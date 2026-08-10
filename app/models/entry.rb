# frozen_string_literal: true

class Entry < ApplicationRecord
  belongs_to :feed
  has_many :entry_reads, dependent: :destroy
  has_many :readers, through: :entry_reads, source: :user

  validates :external_id, presence: true, uniqueness: { scope: :feed_id }
  validates :title, presence: true

  scope :newest_first, -> {
    order(Arel.sql("COALESCE(entries.published_at, entries.created_at) DESC"), id: :desc)
  }
  scope :for_user, ->(user) {
    joins(feed: :subscriptions).where(subscriptions: { user_id: user.id }).distinct
  }
  scope :read_by, ->(user) {
    where(id: EntryRead.where(user_id: user.id).select(:entry_id))
  }
  scope :unread_by, ->(user) {
    where.not(id: EntryRead.where(user_id: user.id).select(:entry_id))
  }
end
