# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sidekiq schedule" do
  it "refreshes subscribed feeds once an hour through Active Job" do
    schedule = YAML.safe_load_file(Rails.root.join("config/schedule.yml"))
    job = schedule.fetch("refresh_feeds_hourly")

    expect(job).to include(
      "cron" => "7 * * * *",
      "class" => "RefreshAllFeedsJob",
      "queue" => "default",
      "active_job" => true
    )
    expect(Fugit::Cron.parse(job.fetch("cron"))).to be_present
  end
end
