# frozen_string_literal: true

# == Schema Information
#
# Table name: campaign_recipients
#
#  id           :bigint           not null, primary key
#  campaign_id  :bigint           not null
#  email        :string(255)      not null
#  status       :string(255)      default("pending"), not null
#  subject_used :string(255)
#  message_id   :string(255)
#  token        :string(255)
#  sent_at      :datetime
#  opened_at    :datetime
#  clicked_at   :datetime
#  error_msg    :text(65535)
#  metadata     :text(65535)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class CampaignRecipient < ApplicationRecord

  STATUSES = %w[pending sent opened clicked failed].freeze

  belongs_to :campaign

  validates :email, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :sent, -> { where(status: "sent") }
  scope :failed, -> { where(status: "failed") }

  def pending?
    status == "pending"
  end

  def mark_sent!(msg_id, tok, subject = nil)
    attrs = {
      status: "sent",
      message_id: msg_id,
      token: tok,
      sent_at: Time.current
    }
    attrs[:subject_used] = subject if subject.present?
    update!(attrs)
  end

  def mark_opened!
    update!(status: "opened", opened_at: Time.current)
  end

  def mark_clicked!
    update!(status: "clicked", clicked_at: Time.current)
  end

  def mark_failed!(error)
    update!(status: "failed", error_msg: error.to_s)
  end

end
