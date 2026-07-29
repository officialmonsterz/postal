# frozen_string_literal: true

class CampaignDeliveryJob

  BATCH_SIZE = 50

  def initialize(campaign_id)
    @campaign = Campaign.find(campaign_id)
    @sent_in_batch = 0
    @failed_in_batch = 0
  end

  def call
    return unless @campaign.status == "running"
    return unless campaigns_enabled?

    @server = @campaign.server
    @credential = @server.credentials.find_by(type: "API") || @server.credentials.first

    unless @credential
      @campaign.pause!
      return
    end

    pending = @campaign.campaign_recipients.pending.order(:id).limit(BATCH_SIZE)
    return complete_if_done if pending.none?

    # Global offset so A/B split is consistent across batches
    offset = @campaign.campaign_recipients.where.not(status: "pending").count

    pending.each_with_index do |recipient, idx|
      @campaign.reload
      break unless @campaign.status == "running"

      recipient.with_lock do
        next unless recipient.pending?

        begin
          global_idx = offset + idx
          subject = @campaign.subject_for_recipient(global_idx)
          send_to_recipient(recipient, subject)
        rescue StandardError => e
          recipient.mark_failed!(e.message)
          @failed_in_batch += 1
          Campaign.where(id: @campaign.id).update_all("total_failed = total_failed + 1")
        end
      end
    end

    if @sent_in_batch.positive?
      Campaign.where(id: @campaign.id).update_all("total_sent = total_sent + #{@sent_in_batch.to_i}")
    end

    if @campaign.campaign_recipients.pending.any?
      self.class.perform_later(@campaign.id)
    else
      complete_if_done
    end
  end

  private

  def campaigns_enabled?
    enabled = begin
      Postal::Config.postal.campaigns_enabled
    rescue StandardError
      true
    end
    enabled.nil? || enabled == true
  end

  def send_to_recipient(recipient, subject)
    template_html = Postal::HtmlTemplates.render(
      @campaign.template_name.presence || "notification",
      recipient_name: recipient.email.to_s.split("@").first,
      recipient_email: recipient.email,
      campaign_name: @campaign.name,
      **safe_template_params
    )

    attributes = {
      to: [recipient.email],
      from: @campaign.sender_email,
      sender: @campaign.sender_email,
      subject: subject,
      html_body: template_html,
      tag: "campaign:#{@campaign.id}",
      custom_headers: {
        "X-Campaign-ID" => @campaign.id.to_s,
        "X-Campaign-Recipient-ID" => recipient.id.to_s
      }
    }
    attributes[:reply_to] = @campaign.reply_to if @campaign.reply_to.present?

    proto = OutgoingMessagePrototype.new(@server, "127.0.0.1", "api", attributes)
    proto.credential = @credential

    unless proto.valid?
      recipient.mark_failed!(proto.errors.first)
      @failed_in_batch += 1
      Campaign.where(id: @campaign.id).update_all("total_failed = total_failed + 1")
      return
    end

    result = proto.create_messages
    if result[recipient.email]
      msg_info = result[recipient.email]
      token = msg_info.is_a?(Hash) ? (msg_info[:token] || msg_info["token"]) : nil
      recipient.mark_sent!(proto.message_id, token, subject)
      @sent_in_batch += 1
    else
      recipient.mark_failed!("No message created")
      @failed_in_batch += 1
      Campaign.where(id: @campaign.id).update_all("total_failed = total_failed + 1")
    end
  end

  def safe_template_params
    raw = @campaign.template_params
    return {} if raw.blank?

    parsed = JSON.parse(raw)
    return {} unless parsed.is_a?(Hash)

    forbidden = %w[
      get_binding binding eval class instance_exec instance_eval
      instance_variable_set instance_variable_get send tap method
      define_method singleton_method public_send __send__
    ]
    parsed.each_with_object({}) do |(k, v), h|
      next if forbidden.include?(k.to_s)

      h[k.to_sym] = v
    end
  rescue JSON::ParserError
    {}
  end

  def complete_if_done
    total_pending = @campaign.campaign_recipients.pending.count
    @campaign.complete! if total_pending.zero?
  end

  class << self
    def perform_later(campaign_id)
      # Run in a background thread so the API request returns immediately.
      # Uses Rails executor + AR connection checkout for thread safety.
      Thread.new do
        Rails.application.executor.wrap do
          ActiveRecord::Base.connection_pool.with_connection do
            new(campaign_id).call
          end
        end
      rescue StandardError => e
        Postal.logger.error "CampaignDeliveryJob failed for campaign_id=#{campaign_id}: #{e.class}: #{e.message}"
      end
    end

    def perform_now(campaign_id)
      new(campaign_id).call
    end
  end

end
