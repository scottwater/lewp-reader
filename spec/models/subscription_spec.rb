# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription, type: :model do
  fixtures :users

  it "allows a user to subscribe to a feed once" do
    feed = Feed.create!(url: "https://example.com/feed.xml")
    described_class.create!(user: users(:one), feed: feed)
    duplicate = described_class.new(user: users(:one), feed: feed)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:feed_id]).to include("has already been taken")
  end
end
