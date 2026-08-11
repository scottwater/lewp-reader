# frozen_string_literal: true

require "json"
require "spec_helper"
require_relative "../support/workspace_command_helpers"

RSpec.describe "workspace lifecycle public commands" do
  include WorkspaceCommandHelpers

  before { build_workspace_repository }
  after { cleanup_workspace_repository }

  it "provisions a linked workspace with leased environment and isolated services" do
    workspace = create_linked_workspace

    result = run_command(workspace.join("bin/workspace-setup"), chdir: workspace)

    expect(result.status).to be_success
    identity = JSON.parse(workspace.join(".workspace-identity.json").read)
    expect(identity).to include(
      "workspace_name" => "feed-fix",
      "mode" => "linked",
      "app_host" => "feed-fix.reader.lewp",
      "compose_project" => "lewp-reader-feed-fix",
      "rails_port" => "41000",
      "vite_port" => "41001",
      "postgres_port" => "41002",
      "redis_port" => "41003",
    )
    expect(workspace.join(".mise.local.toml").read).to include(
      'PORT = "41000"',
      'VITE_PORT = "41001"',
      'PGPORT = "41002"',
      'REDIS_URL = "redis://127.0.0.1:41003/0"',
    )
    expect(command_log.grep(/docker.*up -d --wait/)).not_to be_empty
    expect(command_log.grep(/rails.*RAILS_ENV=development/).join).to include("db:prepare")
    expect(workspace.join("tmp/workspace-seeded")).to exist
    expect(command_log.grep(/rails.*RAILS_ENV=test/).join).to include("db:prepare")
  end

  it "fails before application preparation when Mise does not resolve the lease" do
    workspace = create_linked_workspace

    result = run_command(workspace.join("bin/workspace-setup"), env: { "FAKE_MISE_PORT" => "5432" }, chdir: workspace)

    expect(result.status).not_to be_success
    expect(result.stderr).to include("Mise resolved PGPORT=5432")
    expect(command_log.grep(/docker.*up -d --wait/)).to be_empty
    expect(command_log.grep(/rails/)).to be_empty
  end

  it "repairs an incomplete JavaScript dependency installation with npm ci" do
    workspace = create_linked_workspace
    FileUtils.mkdir_p(workspace.join("node_modules"))

    result = run_command(
      workspace.join("bin/workspace-setup"),
      env: { "FAKE_NPM_LS_STATUS" => "1" },
      chdir: workspace,
    )

    expect(result.status).to be_success
    expect(command_log.grep(/^npm\|/).join("\n")).to include("ls --depth=0", "ci")
  end

  it "stops when Mise trust fails" do
    workspace = create_linked_workspace

    result = run_command(workspace.join("bin/workspace-setup"), env: { "FAKE_MISE_TRUST_STATUS" => "1" }, chdir: workspace)

    expect(result.status).not_to be_success
    expect(command_log.grep(/docker.*up -d --wait/)).to be_empty
    expect(command_log.grep(/^rails\|/)).to be_empty
  end

  it "retains partial identity when service startup fails" do
    workspace = create_linked_workspace

    result = run_command(workspace.join("bin/workspace-setup"), env: { "FAKE_DOCKER_UP_STATUS" => "1" }, chdir: workspace)

    expect(result.status).not_to be_success
    expect(workspace.join(".workspace-identity.json")).to exist
    expect(command_log.grep(/^rails\|/)).to be_empty
  end

  it "retries seeding after application preparation fails" do
    workspace = create_linked_workspace
    failed = run_command(workspace.join("bin/workspace-setup"), env: { "FAKE_RAILS_STATUS" => "1" }, chdir: workspace)
    expect(failed.status).not_to be_success
    expect(workspace.join("tmp/workspace-seeded")).not_to exist
    clear_command_log

    retried = run_command(workspace.join("bin/workspace-setup"), env: { "FAKE_DATABASE_EXISTS" => "1" }, chdir: workspace)

    expect(retried.status).to be_success
    expect(command_log.grep(/rails.*RAILS_ENV=development/).join).to include("db:seed")
    expect(workspace.join("tmp/workspace-seeded")).to exist
  end

  it "preserves an existing database and reseeds only when explicitly requested" do
    workspace = create_linked_workspace
    first = run_command(workspace.join("bin/workspace-setup"), chdir: workspace)
    expect(first.status).to be_success

    clear_command_log
    repeated = run_command(workspace.join("bin/workspace-setup"), env: { "FAKE_DATABASE_EXISTS" => "1" }, chdir: workspace)
    expect(repeated.status).to be_success
    expect(command_log.grep(/rails/).join).not_to include("db:seed")

    clear_command_log
    reseeded = run_command(workspace.join("bin/workspace-setup"), "--reseed", env: { "FAKE_DATABASE_EXISTS" => "1" }, chdir: workspace)
    expect(reseeded.status).to be_success
    development = command_log.grep(/rails.*RAILS_ENV=development/).join
    expect(development).to include("db:reset")
  end

  it "removes Compose volumes before releasing Lewp and leaves the checkout" do
    workspace = create_linked_workspace
    expect(run_command(workspace.join("bin/workspace-setup"), chdir: workspace).status).to be_success
    clear_command_log

    result = run_command(workspace.join("bin/workspace-teardown"), chdir: workspace)

    expect(result.status).to be_success
    down_line = command_log.find { |line| line.include?("down --remove-orphans --volumes") }
    expect(down_line).to include("project=lewp-reader-feed-fix", "pg=41002", "redis=41003", "checkout=#{workspace.realpath}")
    down_index = command_log.index(down_line)
    release_index = command_log.index { |line| line.start_with?("lewp|") && line.include?("release --path") }
    expect(down_index).to be < release_index
    expect(workspace).to be_directory
    expect(workspace.join(".workspace-identity.json")).not_to exist
  end

  it "retains generated authority when Lewp release fails" do
    workspace = create_linked_workspace
    expect(run_command(workspace.join("bin/workspace-setup"), chdir: workspace).status).to be_success
    clear_command_log

    result = run_command(workspace.join("bin/workspace-teardown"), env: { "FAKE_LEWP_RELEASE_STATUS" => "1" }, chdir: workspace)

    expect(result.status).not_to be_success
    expect(workspace.join(".workspace-identity.json")).to exist
    expect(workspace.join(".lewp.local.toml")).to exist
  end

  it "does not release Lewp when Docker cleanup fails" do
    workspace = create_linked_workspace
    expect(run_command(workspace.join("bin/workspace-setup"), chdir: workspace).status).to be_success
    clear_command_log

    result = run_command(workspace.join("bin/workspace-teardown"), env: { "FAKE_DOCKER_DOWN_STATUS" => "1" }, chdir: workspace)

    expect(result.status).not_to be_success
    expect(command_log.grep(/lewp.*release/)).to be_empty
    expect(workspace.join(".workspace-identity.json")).to exist
  end

  it "refuses a Compose project owned by another physical checkout" do
    workspace = create_linked_workspace

    result = run_command(
      workspace.join("bin/workspace-setup"),
      env: { "FAKE_DOCKER_IDS" => "container-1\n", "FAKE_DOCKER_OWNER" => "/other/checkout" },
      chdir: workspace,
    )

    expect(result.status).not_to be_success
    expect(result.stderr).to include("owned by another checkout")
    expect(command_log.select { |line| line.start_with?("lewp|") }).to be_empty
  end

  it "removes an inherited identity before a later Docker failure" do
    workspace = create_linked_workspace
    workspace.join(".workspace-identity.json").write('{"workspace_name":"other","mode":"linked","checkout_path":"/copied/path"}')
    workspace.join(".mise.local.toml").write("inherited")
    workspace.join(".lewp.local.toml").write("inherited")

    result = run_command(
      workspace.join("bin/workspace-setup"),
      env: { "FAKE_DOCKER_PS_STATUS" => "1" },
      chdir: workspace,
    )

    expect(result.status).not_to be_success
    expect(result.stderr).to include("Removing inherited workspace identity")
    expect(workspace.join(".workspace-identity.json")).not_to exist
    expect(workspace.join(".mise.local.toml")).not_to exist
    expect(workspace.join(".lewp.local.toml")).not_to exist
  end

  it "fails closed without deleting existing identity when jq is unavailable" do
    workspace = create_linked_workspace
    checkout_path = workspace.realpath.to_s
    workspace.join(".workspace-identity.json").write(<<~JSON)
      {"workspace_name":"feed-fix","mode":"linked","checkout_path":#{checkout_path.to_json},
       "compose_project":"lewp-reader-feed-fix","app_host":"feed-fix.reader.lewp",
       "rails_port":"41000","vite_port":"41001","postgres_port":"41002","redis_port":"41003"}
    JSON
    workspace.join(".mise.local.toml").write("generated")
    workspace.join(".lewp.local.toml").write(%(host = "feed-fix.reader.lewp"\n))

    result = run_command(
      workspace.join("bin/workspace-setup"),
      env: { "PATH" => path_without_jq },
      chdir: workspace,
    )

    expect(result.status).not_to be_success
    expect(result.stderr).to include("required workspace tool is missing: jq")
    expect(result.stderr).not_to include("Removing inherited workspace identity")
    expect(workspace.join(".workspace-identity.json")).to exist
    expect(workspace.join(".mise.local.toml")).to exist
    expect(workspace.join(".lewp.local.toml")).to exist
  end

  it "derives only linked Compose cleanup when generated identity is missing" do
    workspace = create_linked_workspace
    clear_command_log

    result = run_command(workspace.join("bin/workspace-teardown"), chdir: workspace)

    expect(result.status).to be_success
    expect(result.stderr).to include("skipping Lewp release")
    expect(command_log.grep(/down --remove-orphans --volumes/).join).to include("lewp-reader-feed-fix")
    expect(command_log.select { |line| line.start_with?("lewp|") }).to be_empty
  end

  it "fails closed on malformed teardown identity before Docker" do
    workspace = create_linked_workspace
    workspace.join(".workspace-identity.json").write("not-json")
    clear_command_log

    result = run_command(workspace.join("bin/workspace-teardown"), chdir: workspace)

    expect(result.status).not_to be_success
    expect(result.stderr).to include("malformed")
    expect(command_log.grep(/^docker\|/)).to be_empty
  end

  it "skips Lewp release when a linked checkout loses only its Lewp identity" do
    workspace = create_linked_workspace
    expect(run_command(workspace.join("bin/workspace-setup"), chdir: workspace).status).to be_success
    workspace.join(".lewp.local.toml").delete
    clear_command_log

    result = run_command(workspace.join("bin/workspace-teardown"), chdir: workspace)

    expect(result.status).to be_success
    expect(result.stderr).to include("Lewp identity is missing")
    expect(command_log.select { |line| line.start_with?("lewp|") }).to be_empty
  end

  it "rejects an internally consistent identity aimed at the wrong linked workspace" do
    workspace = create_linked_workspace
    identity = {
      workspace_name: "other",
      mode: "linked",
      checkout_path: workspace.realpath.to_s,
      compose_project: "lewp-reader-other",
      app_host: "other.reader.lewp",
      postgres_port: "41002",
      redis_port: "41003"
    }
    workspace.join(".workspace-identity.json").write(JSON.generate(identity))
    clear_command_log

    result = run_command(workspace.join("bin/workspace-teardown"), chdir: workspace)

    expect(result.status).not_to be_success
    expect(result.stderr).to include("belongs to workspace 'other'")
    expect(command_log.grep(/^docker\|/)).to be_empty
  end

  it "requires generated authority before tearing down the primary checkout" do
    result = run_command(@repository.join("bin/workspace-teardown"), chdir: @repository)

    expect(result.status).not_to be_success
    expect(result.stderr).to include("refusing to infer destructive targets")
    expect(command_log.grep(/docker/)).to be_empty
  end

  it "provisions and tears down the primary only through explicit main mode" do
    ordinary = run_command(@repository.join("bin/workspace-setup"), chdir: @repository)
    expect(ordinary.status).not_to be_success
    expect(ordinary.stderr).to include("requires explicit --main")

    main = run_command(@repository.join("bin/workspace-setup"), "--main", chdir: @repository)
    expect(main.status).to be_success
    identity = JSON.parse(@repository.join(".workspace-identity.json").read)
    expect(identity).to include("workspace_name" => "main", "app_host" => "reader.lewp", "compose_project" => "lewp-reader-main")

    teardown = run_command(@repository.join("bin/workspace-teardown"), chdir: @repository)
    expect(teardown.status).to be_success
    expect(@repository).to be_directory
  end
end
