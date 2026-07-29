# frozen_string_literal: true

module LegacyAPI
  class CampaignsController < BaseController

    before_action :find_campaign, only: [:show, :launch, :pause, :stats, :recipients, :add_recipients]

    # GET /api/v1/campaigns
    def index
      campaigns = @current_credential.server.campaigns.order(created_at: :desc).limit(100)
      render_success campaigns: campaigns.map { |c| serialize_campaign(c) }
    end

    # POST /api/v1/campaigns
    def create
      attrs = campaign_params
      campaign = @current_credential.server.campaigns.new(
        name: attrs[:name],
        subject_a: attrs[:subject_a],
        subject_b: attrs[:subject_b],
        sender_name: attrs[:sender_name],
        sender_email: attrs[:sender_email],
        reply_to: attrs[:reply_to],
        template_name: attrs[:template_name],
        template_params: (attrs[:template_params] || {}).to_json,
        a_split_percent: attrs[:a_split_percent] || 50
      )

      if campaign.save
        if attrs[:recipients].is_a?(Array)
          attrs[:recipients].each do |email|
            next if email.blank?

            campaign.campaign_recipients.create(email: email.to_s.strip)
          end
        end

        render_success campaign: serialize_campaign(campaign)
      else
        render_error "ValidationFailed", message: campaign.errors.full_messages.join(", ")
      end
    end

    # GET /api/v1/campaigns/:id
    def show
      render_success campaign: serialize_campaign(@campaign)
    end

    # POST /api/v1/campaigns/:id/launch
    def launch
      if @campaign.campaign_recipients.count.zero?
        render_error "NoRecipients", message: "Cannot launch a campaign with no recipients"
        return
      end

      @campaign.launch!
      CampaignDeliveryJob.perform_later(@campaign.id)
      render_success campaign: serialize_campaign(@campaign)
    end

    # POST /api/v1/campaigns/:id/pause
    def pause
      @campaign.pause!
      render_success campaign: serialize_campaign(@campaign)
    end

    # GET /api/v1/campaigns/:id/stats
    def stats
      render_success stats: @campaign.recipient_stats
    end

    # GET /api/v1/campaigns/:id/recipients
    def recipients
      page = [(api_params["page"] || 1).to_i, 1].max
      per_page = [[(api_params["per_page"] || 100).to_i, 1].max, 500].min
      recipients = @campaign.campaign_recipients.order(:id)
                           .offset((page - 1) * per_page)
                           .limit(per_page)
      render_success recipients: recipients.map { |r| serialize_recipient(r) },
                     total: @campaign.campaign_recipients.count,
                     page: page,
                     per_page: per_page
    end

    # POST /api/v1/campaigns/:id/recipients
    def add_recipients
      emails = api_params["recipients"]
      unless emails.is_a?(Array) && emails.any?
        render_parameter_error "`recipients` parameter is required and must be a non-empty array"
        return
      end

      added = 0
      emails.each do |email|
        next if email.blank?

        begin
          @campaign.campaign_recipients.create!(email: email.to_s.strip)
          added += 1
        rescue ActiveRecord::RecordInvalid
          next
        end
      end

      render_success added: added, total: @campaign.campaign_recipients.count
    end

    private

    def find_campaign
      # Support both path :id and body/query id
      id = params[:id].presence || api_params["id"]
      @campaign = @current_credential.server.campaigns.find_by(id: id)
      if @campaign.nil?
        render_error "NotFound", message: "Campaign not found"
        throw :abort
      end
    end

    def campaign_params
      p = api_params
      {
        name: p["name"],
        subject_a: p["subject_a"],
        subject_b: p["subject_b"],
        sender_name: p["sender_name"],
        sender_email: p["sender_email"],
        reply_to: p["reply_to"],
        template_name: p["template_name"],
        template_params: p["template_params"],
        a_split_percent: p["a_split_percent"],
        recipients: p["recipients"]
      }
    end

    def serialize_campaign(campaign)
      {
        id: campaign.id,
        name: campaign.name,
        status: campaign.status,
        subject_a: campaign.subject_a,
        subject_b: campaign.subject_b,
        sender_name: campaign.sender_name,
        sender_email: campaign.sender_email,
        reply_to: campaign.reply_to,
        template_name: campaign.template_name,
        a_split_percent: campaign.a_split_percent,
        total_sent: campaign.total_sent,
        total_opened: campaign.total_opened,
        total_clicked: campaign.total_clicked,
        total_failed: campaign.total_failed,
        started_at: campaign.started_at&.to_f,
        completed_at: campaign.completed_at&.to_f,
        created_at: campaign.created_at.to_f,
        recipient_count: campaign.campaign_recipients.count
      }
    end

    def serialize_recipient(r)
      {
        id: r.id,
        email: r.email,
        status: r.status,
        subject_used: r.subject_used,
        sent_at: r.sent_at&.to_f,
        opened_at: r.opened_at&.to_f,
        clicked_at: r.clicked_at&.to_f,
        error_msg: r.error_msg
      }
    end

  end
end
