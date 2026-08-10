# frozen_string_literal: true

require "rails_helper"

RSpec.describe Feeds::Fetcher do
  let(:public_resolver) { ->(_hostname) { [ "93.184.216.34" ] } }

  def response(code, body: "", headers: {})
    instance_double(Net::HTTPResponse, code: code.to_s).tap do |response|
      allow(response).to receive(:[]) { |name| headers[name.downcase] }
      allow(response).to receive(:read_body) { |&block| block.call(body) unless body.empty? }
    end
  end

  def http_boundary(*responses)
    connection = instance_double(Net::HTTP)
    captured_requests = []
    allow(connection).to receive(:request) do |request, &block|
      captured_requests << request
      block.call(responses.shift)
    end

    http = class_double(Net::HTTP)
    allow(http).to receive(:start).and_yield(connection)
    [ http, captured_requests ]
  end

  it "fetches over HTTPS with timeouts, identification, and conditional headers" do
    feed = Feed.new(
      url: "https://feeds.example/news.xml",
      etag: '"version-1"',
      last_modified: "Tue, 01 Aug 2023 12:00:00 GMT"
    )
    http, requests = http_boundary(response(200, body: "<rss />", headers: {
      "etag" => '"version-2"',
      "last-modified" => "Wed, 02 Aug 2023 12:00:00 GMT"
    }))

    result = described_class.new(feed, http: http, resolver: public_resolver).call

    expect(http).to have_received(:start).with(
      "feeds.example",
      443,
      nil,
      nil,
      nil,
      nil,
      use_ssl: true,
      ipaddr: "93.184.216.34",
      open_timeout: described_class::OPEN_TIMEOUT,
      read_timeout: described_class::READ_TIMEOUT,
      write_timeout: described_class::WRITE_TIMEOUT
    )
    expect(requests.first["User-Agent"]).to include("LewpReader")
    expect(requests.first["If-None-Match"]).to eq('"version-1"')
    expect(requests.first["If-Modified-Since"]).to eq("Tue, 01 Aug 2023 12:00:00 GMT")
    expect(result.body).to eq("<rss />")
    expect(result.etag).to eq('"version-2"')
    expect(result.last_modified).to eq("Wed, 02 Aug 2023 12:00:00 GMT")
    expect(result).not_to be_not_modified
  end

  it "treats 304 Not Modified as a successful conditional fetch" do
    feed = Feed.new(url: "https://feeds.example/news.xml", etag: '"version-1"')
    http, = http_boundary(response(304))

    result = described_class.new(feed, http: http, resolver: public_resolver).call

    expect(result).to be_not_modified
    expect(result.body).to be_nil
    expect(result.etag).to eq('"version-1"')
  end

  it "follows up to five relative HTTP redirects" do
    redirects = 5.times.map do |index|
      response(302, headers: { "location" => "/redirect-#{index + 1}.xml" })
    end
    http, requests = http_boundary(*redirects, response(200, body: "<rss />"))
    feed = Feed.new(url: "http://feeds.example/news.xml")

    result = described_class.new(feed, http: http, resolver: public_resolver).call

    expect(result.body).to eq("<rss />")
    expect(requests.size).to eq(6)
    expect(requests.last.path).to eq("/redirect-5.xml")
  end

  it "rejects a sixth redirect" do
    redirects = 6.times.map { response(302, headers: { "location" => "/again.xml" }) }
    http, = http_boundary(*redirects)
    feed = Feed.new(url: "https://feeds.example/news.xml")

    expect { described_class.new(feed, http: http, resolver: public_resolver).call }
      .to raise_error(Feeds::Fetcher::TooManyRedirects)
  end

  it "rejects unsupported URLs and oversized responses" do
    invalid_feed = Feed.new(url: "file:///tmp/feed.xml")
    expect { described_class.new(invalid_feed, resolver: public_resolver).call }
      .to raise_error(Feeds::Fetcher::InvalidUrl)

    oversized = response(200, headers: {
      "content-length" => (described_class::MAX_BODY_BYTES + 1).to_s
    })
    http, = http_boundary(oversized)
    feed = Feed.new(url: "https://feeds.example/news.xml")

    expect { described_class.new(feed, http: http, resolver: public_resolver).call }
      .to raise_error(Feeds::Fetcher::ResponseTooLarge)
  end

  it "reports non-success HTTP responses" do
    http, = http_boundary(response(503))
    feed = Feed.new(url: "https://feeds.example/news.xml")

    expect { described_class.new(feed, http: http, resolver: public_resolver).call }
      .to raise_error(Feeds::Fetcher::HttpError, "Feed request failed with HTTP 503")
  end

  it "rejects a direct private destination before opening a connection" do
    http = class_double(Net::HTTP)
    resolver = ->(_hostname) { [ "127.0.0.1" ] }
    feed = Feed.new(url: "http://127.0.0.1/feed.xml")

    expect(http).not_to receive(:start)
    expect { described_class.new(feed, http: http, resolver: resolver).call }
      .to raise_error(Feeds::Fetcher::UnsafeAddress, "Feed host resolves to a non-public IP address")
  end

  it "rejects redirects to private destinations before requesting them" do
    http, requests = http_boundary(response(302, headers: {
      "location" => "http://169.254.169.254/latest/meta-data/"
    }))
    resolved_hosts = []
    resolver = lambda do |hostname|
      resolved_hosts << hostname
      hostname == "feeds.example" ? [ "93.184.216.34" ] : [ "169.254.169.254" ]
    end
    feed = Feed.new(url: "https://feeds.example/news.xml")

    expect { described_class.new(feed, http: http, resolver: resolver).call }
      .to raise_error(Feeds::Fetcher::UnsafeAddress)
    expect(resolved_hosts).to eq([ "feeds.example", "169.254.169.254" ])
    expect(requests.size).to eq(1)
  end

  it "re-resolves redirects and blocks DNS rebinding while pinning the first request" do
    http, requests = http_boundary(response(302, headers: { "location" => "/moved.xml" }))
    answers = [ [ "93.184.216.34" ], [ "127.0.0.1" ] ]
    resolver = ->(_hostname) { answers.shift }
    feed = Feed.new(url: "https://feeds.example/news.xml")

    expect { described_class.new(feed, http: http, resolver: resolver).call }
      .to raise_error(Feeds::Fetcher::UnsafeAddress)
    expect(http).to have_received(:start).once.with(
      "feeds.example",
      443,
      nil,
      nil,
      nil,
      nil,
      hash_including(ipaddr: "93.184.216.34", use_ssl: true)
    )
    expect(requests.size).to eq(1)
  end
end
