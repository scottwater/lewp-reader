# frozen_string_literal: true

require "rails_helper"

RSpec.describe Feed, type: :model do
  fixtures :users

  it "accepts unique HTTP and HTTPS URLs" do
    expect(described_class.new(url: "https://example.com/feed.xml")).to be_valid
    expect(described_class.new(url: "http://example.com/feed.xml")).to be_valid

    described_class.create!(url: "https://example.com/feed.xml")
    duplicate = described_class.new(url: "https://example.com/feed.xml")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:url]).to include("has already been taken")
  end

  it "rejects URLs that cannot be fetched over HTTP" do
    feed = described_class.new(url: "file:///tmp/feed.xml")

    expect(feed).not_to be_valid
    expect(feed.errors[:url]).to include("must be an HTTP or HTTPS URL")
  end

  it "exposes only distinct feeds with subscribers" do
    subscribed = described_class.create!(url: "https://example.com/subscribed.xml")
    unsubscribed = described_class.create!(url: "https://example.com/unsubscribed.xml")
    subscribed.subscriptions.create!(user: users(:one))
    subscribed.subscriptions.create!(user: users(:two))

    expect(described_class.subscribed).to contain_exactly(subscribed)
    expect(described_class.subscribed).not_to include(unsubscribed)
  end

  it "removes its entries and subscriptions when destroyed" do
    feed = described_class.create!(url: "https://example.com/feed.xml")
    subscription = feed.subscriptions.create!(user: users(:one))
    entry = feed.entries.create!(external_id: "entry-1")

    feed.destroy!

    expect(Subscription.exists?(subscription.id)).to be(false)
    expect(Entry.exists?(entry.id)).to be(false)
  end
end
