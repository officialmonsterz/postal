# frozen_string_literal: true

module LegacyAPI
  class SendController < BaseController

    ERROR_MESSAGES = {
      "NoRecipients" => "There are no recipients defined to receive this message",
      "NoContent" => "There is no content defined for this e-mail",
      "TooManyToAddresses" => "The maximum number of To addresses has been reached (maximum 50)",
      "TooManyCCAddresses" => "The maximum number of CC addresses has been reached (maximum 50)",
      "TooManyBCCAddresses" => "The maximum number of BCC addresses has been reached (maximum 50)",
      "FromAddressMissing" => "The From address is missing and is required",
      "UnauthenticatedFromAddress" => "The From address is not authorised to send mail from this server",
      "AttachmentMissingName" => "An attachment is missing a name",
      "AttachmentMissingData" => "An attachment is missing data",
      "SendLimitExceeded" => "This server has exceeded its hourly send limit",
      "BatchLimitExceeded" => "The batch contains too many messages (maximum 500 per request)"
    }.freeze

    before_action :enforce_send_limit, only: [:message, :raw, :batch]

    # Send a message with the given options
    #
    #   URL:            /api/v1/send/message
    #
    def message
      attributes = build_message_attributes(api_params)

      message = OutgoingMessagePrototype.new(@current_credential.server, request.ip, "api", attributes)
      message.credential = @current_credential
      if message.valid?
        result = message.create_messages
        render_success message_id: message.message_id, messages: result
      else
        render_error message.errors.first, message: ERROR_MESSAGES[message.errors.first]
      end
    end

    # Send a message by providing a raw message
    #
    #   URL:            /api/v1/send/raw
    #
    def raw
      unless api_params["rcpt_to"].is_a?(Array)
        render_parameter_error "`rcpt_to` parameter is required but is missing"
        return
      end

      if api_params["mail_from"].blank?
        render_parameter_error "`mail_from` parameter is required but is missing"
        return
      end

      if api_params["data"].blank?
        render_parameter_error "`data` parameter is required but is missing"
        return
      end

      # Decode the raw message
      raw_message = Base64.decode64(api_params["data"])

      # Parse through mail to get the from/sender headers
      mail = Mail.new(raw_message.split("\r\n\r\n", 2).first)
      from_headers = { "from" => mail.from, "sender" => mail.sender }
      authenticated_domain = @current_credential.server.find_authenticated_domain_from_headers(from_headers)

      # If we're not authenticated, don't continue
      if authenticated_domain.nil?
        render_error "UnauthenticatedFromAddress"
        return
      end

      # Store the result ready to return
      result = { message_id: nil, messages: {} }
      api_params["rcpt_to"].uniq.each do |rcpt_to|
        message = @current_credential.server.message_db.new_message
        message.rcpt_to = rcpt_to
        message.mail_from = api_params["mail_from"]
        message.raw_message = raw_message
        message.received_with_ssl = true
        message.scope = "outgoing"
        message.domain_id = authenticated_domain.id
        message.credential_id = @current_credential.id
        message.bounce = api_params["bounce"] ? true : false
        message.save
        result[:message_id] = message.message_id if result[:message_id].nil?
        result[:messages][rcpt_to] = { id: message.id, token: message.token }
      end
      render_success result
    end

    # Send multiple messages in one API call (max 500)
    #
    #   URL:            /api/v1/send/batch
    #
    def batch
      messages_param = api_params["messages"]
      unless messages_param.is_a?(Array) && messages_param.any?
        render_parameter_error "`messages` parameter is required and must be a non-empty array"
        return
      end

      if messages_param.size > 500
        render_error "BatchLimitExceeded", message: ERROR_MESSAGES["BatchLimitExceeded"]
        return
      end

      results = []
      errors = []

      messages_param.each_with_index do |msg_attrs, idx|
        attributes = build_message_attributes(msg_attrs)

        message = OutgoingMessagePrototype.new(@current_credential.server, request.ip, "api", attributes)
        message.credential = @current_credential

        if message.valid?
          result = message.create_messages
          results << { index: idx, message_id: message.message_id, messages: result, status: "success" }
        else
          errors << {
            index: idx,
            error: message.errors.first,
            message: ERROR_MESSAGES[message.errors.first] || message.errors.first
          }
        end
      end

      if errors.any? && results.empty?
        render_error "BatchFailed", message: "All messages in batch failed", data: { errors: errors }
      else
        render_success sent: results.size, failed: errors.size, results: results, errors: errors
      end
    end

    private

    def build_message_attributes(source)
      attributes = {}
      attributes[:to] = source["to"]
      attributes[:cc] = source["cc"]
      attributes[:bcc] = source["bcc"]
      attributes[:from] = source["from"]
      attributes[:sender] = source["sender"]
      attributes[:subject] = source["subject"]
      attributes[:reply_to] = source["reply_to"]
      attributes[:plain_body] = source["plain_body"]
      attributes[:html_body] = source["html_body"]
      attributes[:bounce] = source["bounce"] ? true : false
      attributes[:tag] = source["tag"]
      attributes[:custom_headers] = source["headers"] if source["headers"]
      attributes[:attachments] = []

      (source["attachments"] || []).each do |attachment|
        next unless attachment.is_a?(Hash)

        attributes[:attachments] << {
          name: attachment["name"],
          content_type: attachment["content_type"],
          data: attachment["data"],
          base64: true
        }
      end

      attributes
    end

    def enforce_send_limit
      server = @current_credential&.server
      return unless server
      return unless server.respond_to?(:send_limit_exceeded?)

      if server.send_limit_exceeded?
        render_error "SendLimitExceeded", message: ERROR_MESSAGES["SendLimitExceeded"]
        throw :abort
      end
    end

  end
end
