# frozen_string_literal: true

class RefreshFeedJob < ApplicationJob
  queue_as :default

  def perform(feed_id)
    feed = Feed.find_by(id: feed_id)
    return unless feed

    Feeds::Importer.new(feed).call
  end
end
