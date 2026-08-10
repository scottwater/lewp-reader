# frozen_string_literal: true

class FeedsController < ReaderController
  before_action :set_feed, only: [ :show, :destroy, :refresh, :mark_all_read ]

  def show
    render_reader(selected_feed: @feed)
  end

  def create
    url = normalize_url(params[:url])
    feed = Feed.find_or_initialize_by(url: url)
    feed.title = URI.parse(url).host if feed.new_record?

    Feed.transaction do
      feed.save!
      Current.user.subscriptions.find_or_create_by!(feed: feed)
    end

    RefreshFeedJob.perform_later(feed.id)
    redirect_to feed_path(feed), notice: "Feed added. Its first refresh is queued."
  rescue URI::InvalidURIError, ArgumentError
    redirect_to dashboard_path, inertia: { errors: { url: [ "Enter a valid http or https feed URL" ] } }
  rescue ActiveRecord::RecordInvalid => error
    redirect_to dashboard_path, inertia: { errors: { url: error.record.errors.full_messages } }
  end

  def destroy
    Current.user.subscriptions.find_by!(feed: @feed).destroy!
    redirect_to dashboard_path, notice: "Feed removed from your reader"
  end

  def refresh
    RefreshFeedJob.perform_later(@feed.id)
    redirect_to feed_path(@feed), notice: "Feed refresh queued"
  end

  def mark_all_read
    mark_entries_read(@feed.entries)
    redirect_to feed_path(@feed), notice: "#{@feed.title} is caught up"
  end

  private

  def set_feed
    @feed = Current.user.feeds.find(params[:id])
  end

  def normalize_url(value)
    uri = URI.parse(value.to_s.strip)
    raise ArgumentError, "Enter an http or https feed URL" unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri.fragment = nil
    uri.to_s
  end
end
