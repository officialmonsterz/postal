# frozen_string_literal: true

class WebhookDeliveryService

  # Exponential backoff (seconds after each failed attempt number):
  # 1 => 1 min, 2 => 2 min, 3 => 4 min, 4 => 8 min, 5 => 16 min, 6 => 32 min, 7 => 64 min
  BASE_DELAY = 1.minute
  MAX_ATTEMPTS = 7

  def initialize(webhook_request:)
    @webhook_request = webhook_request
  end

  def call
    logger.tagged(webhook: @webhook_request.webhook_id, webhook_request: @webhook_request.id) do
      generate_payload
      send_request
      record_attempt
      appreciate_http_result
      update_webhook_request
    end
  end

  def success?
    @success == true
  end

  private

  def generate_payload
    @payload = {
      event: @webhook_request.event,
      timestamp: @webhook_request.created_at.to_f,
      payload: @webhook_request.payload,
      uuid: @webhook_request.uuid
    }.to_json
  end

  def send_request
    @http_result = Postal::HTTP.post(@webhook_request.url,
                                     sign: true,
                                     json: @payload,
                                     timeout: 5)

    @success = (@http_result[:code] >= 200 && @http_result[:code] < 300)
  end

  def record_attempt
    @webhook_request.attempts += 1

    if success?
      @webhook_request.retry_after = nil
    else
      # delay = BASE_DELAY * 2^(attempts-1)
      delay = BASE_DELAY * (2**(@webhook_request.attempts - 1))
      @webhook_request.retry_after = delay.from_now
    end

    @attempt = @webhook_request.server.message_db.webhooks.record(
      event: @webhook_request.event,
      url: @webhook_request.url,
      webhook_id: @webhook_request.webhook_id,
      attempt: @webhook_request.attempts,
      timestamp: Time.now.to_f,
      payload: @webhook_request.payload.to_json,
      uuid: @webhook_request.uuid,
      status_code: @http_result[:code],
      body: @http_result[:body],
      will_retry: @webhook_request.retry_after.present? && @webhook_request.attempts < MAX_ATTEMPTS
    )
  end

  def appreciate_http_result
    if success?
      logger.info "Received #{@http_result[:code]} status code. That's OK."
      @webhook_request.destroy!
      @webhook_request.webhook&.update_column(:last_used_at, Time.current)
      return
    end

    logger.error "Received #{@http_result[:code]} status code. That's not OK."
    @webhook_request.error = "Couldn't send to URL. Code received was #{@http_result[:code]}"
  end

  def update_webhook_request
    # Give up after max attempts
    if @webhook_request.attempts >= MAX_ATTEMPTS
      logger.info "Have tried #{@webhook_request.attempts} times. Giving up."
      @webhook_request.destroy!
      return
    end

    if @webhook_request.retry_after
      delay_seconds = (BASE_DELAY * (2**(@webhook_request.attempts - 1))).to_i
      logger.info "Will retry #{@webhook_request.retry_after} (this was attempt #{@webhook_request.attempts}, delay=#{delay_seconds}s)"
      @webhook_request.locked_by = nil
      @webhook_request.locked_at = nil
      @webhook_request.save!
      return
    end

    logger.info "Have tried #{@webhook_request.attempts} times. Giving up."
    @webhook_request.destroy!
  end

  def logger
    Postal.logger
  end

end
