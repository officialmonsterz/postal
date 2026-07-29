# frozen_string_literal: true

class CreateCampaignRecipients < ActiveRecord::Migration[7.0]
  def change
    create_table :campaign_recipients do |t|
      t.references :campaign, null: false, foreign_key: true
      t.string :email, null: false
      t.string :status, default: "pending", null: false
      t.string :subject_used
      t.string :message_id
      t.string :token
      t.datetime :sent_at
      t.datetime :opened_at
      t.datetime :clicked_at
      t.text :error_msg
      t.text :metadata
      t.timestamps
    end

    add_index :campaign_recipients, [:campaign_id, :status]
    add_index :campaign_recipients, :email
  end
end
