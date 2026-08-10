# frozen_string_literal: true

require "rails_helper"

RSpec.describe RefreshFeedJob, type: :job do
  it "refreshes the feed identified by an integer ID" do
    feed = Feed.create!(url: "https://example.com/feed.xml")
    stub_feed_http(feed_http_response(200, body: feed_fixture("sample.rss.xml")))

    described_class.perform_now(feed.id)

    expect(feed.reload).to be_ready
    expect(feed.entries.count).to eq(3)
  end

  it "does nothing when the feed was deleted before the job runs" do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end
end
