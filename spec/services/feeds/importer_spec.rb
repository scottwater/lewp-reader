# frozen_string_literal: true

require "rails_helper"

RSpec.describe Feeds::Importer do
  it "imports RSS feed metadata and normalized entries" do
    feed = Feed.create!(url: "https://example.com/feed.xml")
    stub_feed_http(feed_http_response(200, body: feed_fixture("sample.rss.xml"), headers: {
      "etag" => '"rss-v1"',
      "last-modified" => "Fri, 04 Aug 2023 12:00:00 GMT"
    }), before_response: -> { expect(feed.reload).to be_refreshing })

    freeze_time do
      result = described_class.new(feed).call

      expect(result.imported_entries).to eq(3)
      expect(feed.reload).to have_attributes(
        title: "Example RSS",
        site_url: "https://example.com/blog",
        description: "A small RSS fixture.",
        etag: '"rss-v1"',
        last_modified: "Fri, 04 Aug 2023 12:00:00 GMT",
        status: "ready",
        fetch_error: nil,
        last_fetched_at: Time.current
      )
    end

    first = feed.entries.find_by!(external_id: "rss-entry-1")
    expect(first).to have_attributes(
      title: "First RSS entry",
      url: "https://example.com/blog/first",
      author: "Ada Lovelace",
      summary: "<p>Short RSS summary.</p>",
      content: "<article>Full <strong>RSS</strong> body.</article>",
      published_at: Time.utc(2023, 8, 1, 12)
    )
    expect(feed.entries.find_by!(title: "URL identified entry").external_id)
      .to eq("https://example.com/blog/by-url")
    expect(feed.entries.find_by!(title: "Content identified entry").external_id)
      .to match(/\A[0-9a-f]{64}\z/)
  end

  it "imports Atom metadata and content" do
    feed = Feed.create!(url: "https://atom.example/feed.xml")
    stub_feed_http(feed_http_response(200, body: feed_fixture("sample.atom.xml")))

    described_class.new(feed).call

    expect(feed.reload).to have_attributes(
      title: "Example Atom",
      site_url: "https://atom.example/",
      description: "A small Atom fixture.",
      status: "ready"
    )
    entry = feed.entries.find_by!(external_id: "tag:atom.example,2023:one")
    expect(entry).to have_attributes(
      title: "Atom & entry",
      url: "https://atom.example/posts/one",
      author: "Grace Hopper",
      summary: "An <em>Atom</em> summary.",
      content: "The <strong>full</strong> Atom body.",
      published_at: Time.utc(2023, 8, 3, 10, 30)
    )
  end

  it "updates the same entries idempotently" do
    feed = Feed.create!(url: "https://example.com/feed.xml")
    body = feed_fixture("sample.rss.xml")
    stub_feed_http(
      feed_http_response(200, body: body),
      feed_http_response(200, body: body)
    )

    described_class.new(feed).call

    expect { described_class.new(feed).call }.not_to change(Entry, :count)
    expect(feed.entries.count).to eq(3)
  end

  it "records a successful 304 without parsing or changing entries" do
    feed = Feed.create!(
      url: "https://example.com/feed.xml",
      status: :error,
      fetch_error: "Previous failure",
      etag: '"rss-v1"',
      last_modified: "Fri, 04 Aug 2023 12:00:00 GMT"
    )
    entry = feed.entries.create!(external_id: "existing")
    requests = stub_feed_http(feed_http_response(304))

    freeze_time do
      result = described_class.new(feed).call

      expect(result).to be_not_modified
      expect(feed.reload).to have_attributes(
        status: "ready",
        fetch_error: nil,
        last_fetched_at: Time.current,
        etag: '"rss-v1"',
        last_modified: "Fri, 04 Aug 2023 12:00:00 GMT"
      )
    end
    expect(feed.entries).to contain_exactly(entry)
    expect(requests.first["If-None-Match"]).to eq('"rss-v1"')
    expect(requests.first["If-Modified-Since"]).to eq("Fri, 04 Aug 2023 12:00:00 GMT")
  end

  it "persists fetch errors and re-raises them for job retrying" do
    feed = Feed.create!(url: "https://example.com/feed.xml")
    stub_feed_http(feed_http_response(503))

    expect { described_class.new(feed).call }
      .to raise_error(Feeds::Fetcher::HttpError, "Feed request failed with HTTP 503")
    expect(feed.reload).to have_attributes(
      status: "error",
      fetch_error: "Feed request failed with HTTP 503",
      last_fetched_at: nil
    )
  end
end
