# frozen_string_literal: true

class EntryRead < ApplicationRecord
  belongs_to :user
  belongs_to :entry

  before_validation :set_read_at, on: :create

  validates :entry_id, uniqueness: { scope: :user_id }
  validates :read_at, presence: true

  private

  def set_read_at
    self.read_at ||= Time.current
  end
end
