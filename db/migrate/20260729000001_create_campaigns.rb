# frozen_string_literal: true

class CreateCampaigns < ActiveRecord::Migration[7.0]
  def change
    create_table :campaigns do |t|
      t.string :name, null: false
      t.references :server, null: false, foreign_key: true
      t.string :status, default: "draft", null: false
      t.string :subject_a
      t.string :subject_b
      t.string :sender_name
      t.string :sender_email
      t.string :reply_to
      t.string :template_name
      t.text :template_params
      t.integer :a_split_percent, default: 50
      t.integer :total_sent, default: 0
      t.integer :total_opened, default: 0
      t.integer :total_clicked, default: 0
      t.integer :total_failed, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :campaigns, [:server_id, :status]
  end
end
