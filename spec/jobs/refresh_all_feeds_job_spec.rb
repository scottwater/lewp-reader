# frozen_string_literal: true

require "rails_helper"

RSpec.describe RefreshAllFeedsJob, type: :job do
  fixtures :users

  it "enqueues each distinctly subscribed feed exactly once" do
    shared = Feed.create!(url: "https://example.com/shared.xml")
    single = Feed.create!(url: "https://example.com/single.xml")
    unsubscribed = Feed.create!(url: "https://example.com/unsubscribed.xml")
    shared.subscriptions.create!(user: users(:one))
    shared.subscriptions.create!(user: users(:two))
    single.subscriptions.create!(user: users(:one))

    described_class.perform_now

    expect(RefreshFeedJob).to have_been_enqueued.with(shared.id).exactly(:once)
    expect(RefreshFeedJob).to have_been_enqueued.with(single.id).exactly(:once)
    expect(RefreshFeedJob).not_to have_been_enqueued.with(unsubscribed.id)
  end
end
