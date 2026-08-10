# frozen_string_literal: true

class WidenSessionUserIdForPostgresql < ActiveRecord::Migration[8.1]
  def change
    change_column :sessions, :user_id, :bigint, null: false
  end
end
