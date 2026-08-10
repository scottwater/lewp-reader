# frozen_string_literal: true

require "rails_helper"

RSpec.describe EntryRead, type: :model do
  fixtures :users

  it "records the first read time and prevents duplicates" do
    feed = Feed.create!(url: "https://example.com/feed.xml")
    entry = feed.entries.create!(external_id: "entry-1")
    read = described_class.create!(user: users(:one), entry: entry)
    duplicate = described_class.new(user: users(:one), entry: entry)

    expect(read.read_at).to be_within(1.second).of(Time.current)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:entry_id]).to include("has already been taken")
  end
end
