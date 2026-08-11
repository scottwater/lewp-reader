# frozen_string_literal: true

require "json"
require "open3"
require "spec_helper"

RSpec.describe "workspace environment consumption at process boundaries" do
  def run_rails(code, env = {})
    Open3.capture3(
      { "RAILS_ENV" => "development", "APP_HOST" => nil, "PORT" => nil }.merge(env),
      "bin/rails", "runner", code,
    )
  end

  it "keeps localhost URL generation defaults without workspace variables" do
    stdout, stderr, status = run_rails('puts Rails.application.config.action_mailer.default_url_options.to_json')

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq("host" => "localhost", "port" => 3000)
  end

  it "applies the leased host and port to URL generation and host authorization" do
    code = <<~'RUBY'
      puts Rails.application.config.action_mailer.default_url_options.to_json
      puts Rails.application.config.hosts.to_a.grep(/reader\.lewp/).to_json
    RUBY
    stdout, stderr, status = run_rails(code, "APP_HOST" => "feed-fix.reader.lewp", "PORT" => "41000")

    expect(status).to be_success, stderr
    lines = stdout.lines
    expect(JSON.parse(lines.fetch(0))).to eq("host" => "feed-fix.reader.lewp", "port" => 41_000)
    expect(JSON.parse(lines.fetch(1))).to eq([ "feed-fix.reader.lewp" ])
  end

  it "passes libpq workspace values into development database configuration" do
    code = <<~'RUBY'
      config = ActiveRecord::Base.configurations.configs_for(env_name: "development").first.configuration_hash
      puts config.slice(:host, :port, :username, :database).to_json
    RUBY
    stdout, stderr, status = run_rails(
      code,
      "PGHOST" => "127.0.0.1",
      "PGPORT" => "41002",
      "PGUSER" => "postgres",
    )

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq(
      "host" => "127.0.0.1",
      "port" => 41_002,
      "username" => "postgres",
      "database" => "lewp_reader_development",
    )
  end

  it "rejects malformed Vite port input at configuration load" do
    script = 'await import(`./vite.config.ts?spec=${Date.now()}`).then((m) => m.default({ command: "serve", mode: "development" }))'
    _stdout, stderr, status = Open3.capture3(
      { "VITE_PORT" => "not-a-port" },
      "node", "--input-type=module", "-e", script,
    )

    expect(status).not_to be_success
    expect(stderr).to include("VITE_PORT must be a numeric TCP port")
  end

  it "configures Vite with the leased port and strict selection" do
    script = <<~'JS'
      const imported = await import(`./vite.config.ts?spec=${Date.now()}`)
      const config = imported.default({ command: "serve", mode: "development" })
      console.log(JSON.stringify(config.server))
    JS
    stdout, stderr, status = Open3.capture3(
      { "VITE_PORT" => "41001" },
      "node", "--input-type=module", "-e", script,
    )

    expect(status).to be_success, stderr
    expect(JSON.parse(stdout)).to eq("port" => 41_001, "strictPort" => true)
  end
end
