# frozen_string_literal: true

class Feed < ApplicationRecord
  has_many :subscriptions, dependent: :destroy
  has_many :users, through: :subscriptions
  has_many :entries, dependent: :destroy

  enum :status, {
    pending: "pending",
    refreshing: "refreshing",
    ready: "ready",
    error: "error"
  }, validate: true

  normalizes :url, with: -> { _1.strip }

  validates :url, presence: true, uniqueness: true
  validates :title, presence: true
  validate :url_must_be_http

  scope :subscribed, -> { joins(:subscriptions).distinct }
  scope :starters, -> { where(starter: true) }

  private

  def url_must_be_http
    return if url.blank?

    uri = URI.parse(url)
    return if uri.is_a?(URI::HTTP) && uri.host.present? && %w[http https].include?(uri.scheme)

    errors.add(:url, "must be an HTTP or HTTPS URL")
  rescue URI::InvalidURIError
    errors.add(:url, "must be an HTTP or HTTPS URL")
  end
end
