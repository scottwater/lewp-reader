# frozen_string_literal: true

starter_feed_urls = [
  "https://andycroll.com/index.xml",
  "https://seths.blog/feed/",
  "https://island94.org/feed.xml",
  "https://evilmartians.com/chronicles.atom",
  "https://scottw.com/feed.xml"
].freeze

starter_feeds = starter_feed_urls.map do |url|
  feed = Feed.find_or_initialize_by(url: url)
  feed.title = URI.parse(url).host if feed.new_record?
  feed.starter = true
  feed.save!
  feed
end

demo_user = User.find_or_create_by!(email: DemoSessionsController::DEMO_EMAIL) do |user|
  user.name = "Lewp Reader Demo"
  user.password = "lewp-reader-demo"
  user.password_confirmation = "lewp-reader-demo"
  user.verified = true
end

starter_feeds.each do |feed|
  demo_user.subscriptions.find_or_create_by!(feed: feed)
  RefreshFeedJob.perform_later(feed.id)
end

puts "Seeded #{starter_feeds.size} starter feeds and #{demo_user.email}"
