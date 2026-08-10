# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Database seeds" do
  let(:starter_urls) do
    [
      "https://andycroll.com/index.xml",
      "https://seths.blog/feed/",
      "https://island94.org/feed.xml",
      "https://evilmartians.com/chronicles.atom",
      "https://scottw.com/feed.xml"
    ]
  end

  it "idempotently subscribes the demo user to the five starter feeds" do
    clear_enqueued_jobs

    expect { load Rails.root.join("db/seeds.rb") }.to output(/Seeded 5 starter feeds/).to_stdout

    demo_user = User.find_by!(email: DemoSessionsController::DEMO_EMAIL)
    expect(Feed.starters.pluck(:url)).to match_array(starter_urls)
    expect(demo_user.feeds.pluck(:url)).to match_array(starter_urls)
    expect(RefreshFeedJob).to have_been_enqueued.exactly(5).times

    counts = [ Feed.count, User.count, Subscription.count ]
    expect { load Rails.root.join("db/seeds.rb") }.to output(/Seeded 5 starter feeds/).to_stdout
    expect([ Feed.count, User.count, Subscription.count ]).to eq(counts)
  end
end
