# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Feeds", type: :request do
  fixtures :users

  before do
    sign_in users(:one)
    clear_enqueued_jobs
    clear_performed_jobs
  end

  describe "POST /feeds" do
    it "adds a subscription and queues the first refresh without performing it" do
      post feeds_path, params: { url: "  https://feeds.example/news.xml#latest  " }

      feed = Feed.find_by!(url: "https://feeds.example/news.xml")
      expect(response).to redirect_to(feed_path(feed))
      expect(flash[:notice]).to eq("Feed added. Its first refresh is queued.")
      expect(users(:one).subscriptions.exists?(feed: feed)).to be(true)
      expect(feed).to be_pending
      expect(RefreshFeedJob).to have_been_enqueued.with(feed.id).once
      expect(performed_jobs).to be_empty
    end

    it "does not duplicate an existing subscription" do
      feed = Feed.create!(url: "https://feeds.example/news.xml", title: "News")
      users(:one).subscriptions.create!(feed: feed)

      expect {
        post feeds_path, params: { url: feed.url }
      }.not_to change(Subscription, :count)

      expect(response).to redirect_to(feed_path(feed))
      expect(RefreshFeedJob).to have_been_enqueued.with(feed.id).once
    end

    it "returns an Inertia form error for an invalid URL" do
      expect {
        post feeds_path, params: { url: "file:///tmp/private.xml" }
      }.not_to change(Feed, :count)

      expect(response).to redirect_to(dashboard_path)
      expect(session[:inertia_errors]).to eq(url: [ "Enter a valid http or https feed URL" ])
      expect(enqueued_jobs).to be_empty
    end
  end

  describe "GET /feeds/:id" do
    it "renders the reader with the selected feed's entries" do
      selected_feed = subscribed_feed_for(users(:one), "https://feeds.example/selected.xml", "Selected")
      selected_entry = selected_feed.entries.create!(external_id: "selected", title: "Selected entry")
      other_feed = subscribed_feed_for(users(:one), "https://feeds.example/other.xml", "Other")
      other_feed.entries.create!(external_id: "other", title: "Other entry")

      get feed_path(selected_feed)

      expect(response).to have_http_status(:success)
      expect(inertia).to render_component("reader/index")
      expect(inertia.props[:selected_feed]).to include("id" => selected_feed.id, "title" => "Selected")
      expect(inertia.props[:entries].pluck(:id)).to eq([ selected_entry.id ])
    end
  end

  describe "POST /feeds/:id/refresh" do
    it "queues a refresh without running it" do
      feed = subscribed_feed_for(users(:one), "https://feeds.example/news.xml", "News")

      post refresh_feed_path(feed)

      expect(response).to redirect_to(feed_path(feed))
      expect(flash[:notice]).to eq("Feed refresh queued")
      expect(RefreshFeedJob).to have_been_enqueued.with(feed.id).once
      expect(performed_jobs).to be_empty
    end
  end

  describe "PATCH /feeds/:id/mark_all_read" do
    it "marks that feed read only for the current user" do
      feed = subscribed_feed_for(users(:one), "https://feeds.example/news.xml", "News")
      feed.subscriptions.create!(user: users(:two))
      first_entry = feed.entries.create!(external_id: "first")
      second_entry = feed.entries.create!(external_id: "second")
      EntryRead.create!(user: users(:one), entry: first_entry)

      expect {
        patch mark_all_read_feed_path(feed)
      }.to change { users(:one).entry_reads.count }.by(1)

      expect(response).to redirect_to(feed_path(feed))
      expect(flash[:notice]).to eq("News is caught up")
      expect(users(:one).entry_reads.where(entry: [ first_entry, second_entry ]).count).to eq(2)
      expect(users(:two).entry_reads.where(entry: [ first_entry, second_entry ])).to be_empty
    end
  end

  describe "DELETE /feeds/:id" do
    it "removes only the current user's subscription" do
      feed = subscribed_feed_for(users(:one), "https://feeds.example/news.xml", "News")
      other_subscription = feed.subscriptions.create!(user: users(:two))

      expect {
        delete feed_path(feed)
      }.to change { users(:one).subscriptions.count }.by(-1)

      expect(response).to redirect_to(dashboard_path)
      expect(flash[:notice]).to eq("Feed removed from your reader")
      expect(Feed.exists?(feed.id)).to be(true)
      expect(Subscription.exists?(other_subscription.id)).to be(true)
    end
  end

  describe "feed ownership" do
    it "returns not found from every feed endpoint for another user's feed" do
      private_feed = subscribed_feed_for(users(:two), "https://private.example/feed.xml", "Private")

      get feed_path(private_feed)
      expect(response).to have_http_status(:not_found)

      post refresh_feed_path(private_feed)
      expect(response).to have_http_status(:not_found)

      patch mark_all_read_feed_path(private_feed)
      expect(response).to have_http_status(:not_found)

      delete feed_path(private_feed)
      expect(response).to have_http_status(:not_found)
      expect(users(:two).subscriptions.exists?(feed: private_feed)).to be(true)
      expect(enqueued_jobs).to be_empty
    end
  end

  def subscribed_feed_for(user, url, title)
    Feed.create!(url: url, title: title).tap do |feed|
      feed.subscriptions.create!(user: user)
    end
  end
end
