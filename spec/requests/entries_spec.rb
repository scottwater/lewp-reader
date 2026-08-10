# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entries", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "PATCH /entries/:id" do
    it "marks one entry read and redirects to its reader view" do
      feed = Feed.create!(url: "https://feeds.example/news.xml", title: "News")
      feed.subscriptions.create!(user: users(:one))
      feed.subscriptions.create!(user: users(:two))
      entry = feed.entries.create!(
        external_id: "entry-1",
        title: "A careful read",
        content: '<p>Hello <strong>reader</strong>.</p><script>alert("no")</script>'
      )
      EntryRead.create!(user: users(:two), entry: entry)

      expect {
        patch entry_path(entry)
      }.to change { users(:one).entry_reads.count }.by(1)

      expect(response).to redirect_to(entry_path(entry))

      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(inertia).to render_component("reader/index")
      expect(inertia.props[:selected_feed]).to include("id" => feed.id)
      expect(inertia.props[:selected_entry]).to include(
        "id" => entry.id,
        "title" => "A careful read",
        "read" => true
      )
      expect(inertia.props.dig(:selected_entry, :content_html)).to include("<strong>reader</strong>")
      expect(inertia.props.dig(:selected_entry, :content_html)).not_to include("<script")
      expect(users(:two).entry_reads.where(entry: entry).count).to eq(1)
    end

    it "does not create duplicate read records" do
      feed = Feed.create!(url: "https://feeds.example/news.xml")
      feed.subscriptions.create!(user: users(:one))
      entry = feed.entries.create!(external_id: "entry-1")
      EntryRead.create!(user: users(:one), entry: entry)

      expect {
        patch entry_path(entry)
      }.not_to change(EntryRead, :count)

      expect(response).to redirect_to(entry_path(entry))
    end

    it "preserves the all-entries scope and page through the reader redirect" do
      feed = Feed.create!(url: "https://feeds.example/news.xml", title: "News")
      feed.subscriptions.create!(user: users(:one))
      entry = feed.entries.create!(external_id: "entry-1", title: "A careful read")

      patch entry_path(entry), params: { scope: "all", page: 2 }

      expect(response).to redirect_to(entry_path(entry, scope: "all", page: 2))

      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(inertia.props[:selected_feed]).to be_nil
      expect(inertia.props[:selected_entry]).to include("id" => entry.id)
      expect(inertia.props[:pagination]).to include("page" => 2)
    end
  end

  describe "GET /entries/:id" do
    it "makes relative article links and images absolute without restoring unsafe URLs" do
      feed = Feed.create!(
        url: "https://andycroll.com/feed.xml",
        site_url: "https://andycroll.com/",
        title: "Andy Croll"
      )
      feed.subscriptions.create!(user: users(:one))
      entry = feed.entries.create!(
        external_id: "relative-links",
        title: "Relative links",
        url: "https://andycroll.com/ruby/a-careful-read/",
        content: <<~HTML
          <p>
            <a href="../archive">Archive</a>
            <img src="/images/chart.png" alt="Chart">
            <a href="javascript:alert('no')">Unsafe</a>
          </p>
        HTML
      )

      get entry_path(entry)

      html = inertia.props.dig(:selected_entry, :content_html)
      expect(html).to include('href="https://andycroll.com/ruby/archive"')
      expect(html).to include('src="https://andycroll.com/images/chart.png"')
      expect(html).not_to include("javascript:")
    end

    it "uses the feed site URL when an article URL is unavailable" do
      feed = Feed.create!(
        url: "https://andycroll.com/feed.xml",
        site_url: "https://andycroll.com/articles/",
        title: "Andy Croll"
      )
      feed.subscriptions.create!(user: users(:one))
      entry = feed.entries.create!(
        external_id: "site-relative-link",
        title: "Site-relative link",
        content: '<p><a href="archive">Archive</a></p>'
      )

      get entry_path(entry)

      expect(inertia.props.dig(:selected_entry, :content_html))
        .to include('href="https://andycroll.com/articles/archive"')
    end
  end

  describe "entry ownership" do
    it "returns not found when the entry belongs only to another user" do
      private_feed = Feed.create!(url: "https://private.example/feed.xml")
      private_feed.subscriptions.create!(user: users(:two))
      private_entry = private_feed.entries.create!(external_id: "private-entry")

      get entry_path(private_entry)
      expect(response).to have_http_status(:not_found)

      expect {
        patch entry_path(private_entry)
      }.not_to change(EntryRead, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
