# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reader", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "GET /dashboard" do
    it "renders the signed-in user's feeds and entries with read state" do
      subscribed_feed = Feed.create!(
        url: "https://reader.example/feed.xml",
        title: "Reader Feed",
        status: :ready
      )
      subscribed_feed.subscriptions.create!(user: users(:one))
      read_entry = subscribed_feed.entries.create!(
        external_id: "read-entry",
        title: "Already read",
        summary: "<p>A <strong>useful</strong> summary.</p>",
        published_at: 2.hours.ago
      )
      unread_entry = subscribed_feed.entries.create!(
        external_id: "unread-entry",
        title: "Still unread",
        published_at: 1.hour.ago
      )
      EntryRead.create!(user: users(:one), entry: read_entry)

      private_feed = Feed.create!(url: "https://private.example/feed.xml", title: "Private Feed")
      private_feed.subscriptions.create!(user: users(:two))
      private_feed.entries.create!(external_id: "private-entry", title: "Someone else's entry")

      get dashboard_path

      expect(response).to have_http_status(:success)
      expect(inertia).to be_inertia_response
      expect(inertia).to render_component("reader/index")
      expect(inertia.props.dig(:auth, :user)).to include(
        "id" => users(:one).id,
        "name" => users(:one).name,
        "email" => users(:one).email
      )
      expect(inertia.props[:feeds]).to contain_exactly(include(
        "id" => subscribed_feed.id,
        "title" => "Reader Feed",
        "entry_count" => 2,
        "unread_count" => 1
      ))
      expect(inertia.props[:entries]).to match([
        include("id" => unread_entry.id, "read" => false),
        include("id" => read_entry.id, "summary" => "A useful summary.", "read" => true)
      ])
      expect(inertia.props[:selected_feed]).to be_nil
      expect(inertia.props[:selected_entry]).to be_nil
    end

    it "paginates entries one hundred at a time" do
      feed = Feed.create!(url: "https://reader.example/feed.xml", title: "Reader Feed")
      feed.subscriptions.create!(user: users(:one))
      published_at = Time.zone.parse("2026-08-09 12:00:00")
      101.times do |index|
        feed.entries.create!(
          external_id: "entry-#{index}",
          title: "Entry #{index}",
          published_at: published_at - index.minutes
        )
      end

      get dashboard_path

      expect(inertia.props[:entries].size).to eq(100)
      expect(inertia.props[:entries].first[:title]).to eq("Entry 0")
      expect(inertia.props[:entries].last[:title]).to eq("Entry 99")
      expect(inertia.props[:pagination]).to eq(
        "page" => 1,
        "has_newer" => false,
        "has_older" => true
      )

      get dashboard_path, params: { page: 2 }

      expect(inertia.props[:entries].pluck(:title)).to eq([ "Entry 100" ])
      expect(inertia.props[:pagination]).to eq(
        "page" => 2,
        "has_newer" => true,
        "has_older" => false
      )
    end

    it "uses the first page when the page parameter is invalid" do
      feed = Feed.create!(url: "https://reader.example/feed.xml", title: "Reader Feed")
      feed.subscriptions.create!(user: users(:one))
      entry = feed.entries.create!(external_id: "entry-1", title: "First entry")

      get dashboard_path, params: { page: "not-a-page" }

      expect(inertia.props[:entries].pluck(:id)).to eq([ entry.id ])
      expect(inertia.props[:pagination]).to include(
        "page" => 1,
        "has_newer" => false
      )
    end

    it "requires authentication" do
      sign_out

      get dashboard_path

      expect(response).to redirect_to(sign_in_path)
    end
  end

  describe "PATCH /reader/mark_all_read" do
    it "marks every subscribed entry read without touching another user's entries" do
      subscribed_feed = Feed.create!(url: "https://reader.example/feed.xml")
      subscribed_feed.subscriptions.create!(user: users(:one))
      already_read = subscribed_feed.entries.create!(external_id: "already-read")
      newly_read = subscribed_feed.entries.create!(external_id: "newly-read")
      EntryRead.create!(user: users(:one), entry: already_read)

      private_feed = Feed.create!(url: "https://private.example/feed.xml")
      private_feed.subscriptions.create!(user: users(:two))
      private_entry = private_feed.entries.create!(external_id: "private-entry")

      expect {
        patch mark_all_read_reader_path
      }.to change { users(:one).entry_reads.count }.by(1)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to eq("Everything is caught up")
      expect(users(:one).entry_reads.where(entry: [ already_read, newly_read ]).count).to eq(2)
      expect(users(:one).entry_reads.exists?(entry: private_entry)).to be(false)

      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(inertia.props[:feeds].first[:unread_count]).to eq(0)
    end
  end
end
