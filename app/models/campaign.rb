# frozen_string_literal: true

# == Schema Information
#
# Table name: campaigns
#
#  id              :bigint           not null, primary key
#  name            :string(255)      not null
#  server_id       :bigint           not null
#  status          :string(255)      default("draft"), not null
#  subject_a       :string(255)
#  subject_b       :string(255)
#  sender_name     :string(255)
#  sender_email    :string(255)
#  reply_to        :string(255)
#  template_name   :string(255)
#  template_params :text(65535)
#  a_split_percent :integer          default(50)
#  total_sent      :integer          default(0)
#  total_opened    :integer          default(0)
#  total_clicked   :integer          default(0)
#  total_failed    :integer          default(0)
#  started_at      :datetime
#  completed_at    :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class Campaign < ApplicationRecord

  STATUSES = %w[draft running paused completed].freeze

  belongs_to :server
  has_many :campaign_recipients, dependent: :destroy

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :sender_email, presence: true, if: :running_or_completed?
  validates :a_split_percent, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  scope :draft, -> { where(status: "draft") }
  scope :running, -> { where(status: "running") }
  scope :completed, -> { where(status: "completed") }

  def running_or_completed?
    %w[running completed].include?(status)
  end

  def subject_for_recipient(recipient_index)
    return subject_a if subject_b.blank?
    return subject_a if a_split_percent.nil? || a_split_percent >= 100
    return subject_b if a_split_percent <= 0

    # Deterministic split based on global index
    (recipient_index % 100) < a_split_percent ? subject_a : subject_b
  end

  def launch!
    update!(status: "running", started_at: Time.current)
  end

  def pause!
    update!(status: "paused")
  end

  def complete!
    update!(status: "completed", completed_at: Time.current)
  end

  def recipient_stats
    {
      total: campaign_recipients.count,
      pending: campaign_recipients.where(status: "pending").count,
      sent: campaign_recipients.where(status: "sent").count,
      opened: campaign_recipients.where(status: "opened").count,
      clicked: campaign_recipients.where(status: "clicked").count,
      failed: campaign_recipients.where(status: "failed").count
    }
  end

end
