# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entry, type: :model do
  fixtures :users

  let(:feed) { Feed.create!(url: "https://example.com/feed.xml") }

  it "requires a feed-scoped external ID" do
    feed.entries.create!(external_id: "same-id")
    duplicate = feed.entries.new(external_id: "same-id")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:external_id]).to include("has already been taken")
  end

  it "orders undated and dated entries by their effective recency" do
    old = feed.entries.create!(external_id: "old", published_at: 3.days.ago)
    recent = feed.entries.create!(external_id: "recent", published_at: 1.hour.ago)
    undated = feed.entries.create!(external_id: "undated", created_at: 2.days.ago)

    expect(described_class.newest_first).to eq([ recent, undated, old ])
  end

  it "scopes entries to a user's subscriptions and read state" do
    feed.subscriptions.create!(user: users(:one))
    unread = feed.entries.create!(external_id: "unread")
    read = feed.entries.create!(external_id: "read")
    other_feed_entry = Feed.create!(url: "https://other.example/feed.xml").entries.create!(external_id: "other")
    EntryRead.create!(user: users(:one), entry: read)

    expect(described_class.for_user(users(:one))).to contain_exactly(unread, read)
    expect(described_class.unread_by(users(:one))).to include(unread, other_feed_entry)
    expect(described_class.unread_by(users(:one))).not_to include(read)
  end

  it "removes per-user read records when destroyed" do
    entry = feed.entries.create!(external_id: "entry-1")
    read = EntryRead.create!(user: users(:one), entry: entry)

    entry.destroy!

    expect(EntryRead.exists?(read.id)).to be(false)
  end
end
