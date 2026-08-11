# frozen_string_literal: true

require "json"
require "spec_helper"
require_relative "../support/workspace_command_helpers"

RSpec.describe "optional Herdr workspace lifecycle" do
  include WorkspaceCommandHelpers

  before do
    build_workspace_repository
    install_fake_herdr
    @workspace = create_linked_workspace
  end
  after { cleanup_workspace_repository }

  def marker_path
    git_dir = git("rev-parse", "--absolute-git-dir", chdir: @workspace).strip
    Pathname(git_dir).join("lewp-reader-herdr-workspace")
  end

  def active_list
    JSON.generate(
      id: "list",
      result: { type: "workspace_list", workspaces: [ { workspace_id: "w99", worktree: { checkout_path: @workspace.realpath.to_s } } ] },
    )
  end

  it "silently skips an installed Herdr when no active context exists" do
    result = run_command(@workspace.join("bin/workspace-setup"), chdir: @workspace)

    expect(result.status).to be_success, result.stderr
    expect(command_log.grep(/^herdr\|/)).to be_empty
    expect(marker_path).not_to exist
  end

  it "creates and records a workspace only with active Herdr context" do
    result = run_command(
      @workspace.join("bin/workspace-setup"),
      chdir: @workspace,
      env: { "HERDR_WORKSPACE_ID" => "w1" },
    )

    expect(result.status).to be_success, result.stderr
    expect(marker_path.read.strip).to eq("w99")
    expect(command_log.grep(/herdr.*workspace create/)).not_to be_empty
  end

  it "focuses a recorded active workspace instead of creating another" do
    marker_path.write("w99\n")
    list = active_list

    result = run_command(
      @workspace.join("bin/workspace-setup"),
      chdir: @workspace,
      env: { "HERDR_WORKSPACE_ID" => "w1", "FAKE_HERDR_LIST" => list },
    )

    expect(result.status).to be_success, result.stderr
    expect(command_log.grep(/herdr.*workspace focus w99/)).not_to be_empty
    expect(command_log.grep(/herdr.*workspace create/)).to be_empty
  end

  it "replaces a stale marker only after a valid list proves it inactive" do
    marker_path.write("w88\n")

    result = run_command(
      @workspace.join("bin/workspace-setup"),
      chdir: @workspace,
      env: { "HERDR_WORKSPACE_ID" => "w1" },
    )

    expect(result.status).to be_success, result.stderr
    expect(marker_path.read.strip).to eq("w99")
    expect(command_log.grep(/herdr.*workspace create/)).not_to be_empty
  end

  it "retains a recorded marker when Herdr list JSON is malformed" do
    marker_path.write("w88\n")

    result = run_command(
      @workspace.join("bin/workspace-setup"),
      chdir: @workspace,
      env: { "HERDR_WORKSPACE_ID" => "w1", "FAKE_HERDR_MALFORMED" => "1" },
    )

    expect(result.status).not_to be_success
    expect(marker_path.read.strip).to eq("w88")
    expect(command_log.grep(/herdr.*workspace create/)).to be_empty
  end

  it "refuses an active marker owned by another checkout before Docker" do
    marker_path.write("w99\n")
    list = JSON.generate(
      id: "list",
      result: { type: "workspace_list", workspaces: [ { workspace_id: "w99", worktree: { checkout_path: "/other/checkout" } } ] },
    )

    result = run_command(
      @workspace.join("bin/workspace-teardown"),
      chdir: @workspace,
      env: { "FAKE_HERDR_LIST" => list },
    )

    expect(result.status).not_to be_success
    expect(result.stderr).to include("belongs to another checkout")
    expect(command_log.grep(/^docker\|/)).to be_empty
  end

  it "fails closed when Herdr list entries have an incomplete schema" do
    marker_path.write("w99\n")
    malformed_list = '{"id":"list","result":{"type":"workspace_list","workspaces":[{"label":"missing-id"}]}}'

    setup = run_command(
      @workspace.join("bin/workspace-setup"),
      chdir: @workspace,
      env: { "HERDR_WORKSPACE_ID" => "w1", "FAKE_HERDR_LIST" => malformed_list },
    )
    expect(setup.status).not_to be_success
    expect(marker_path.read.strip).to eq("w99")
    clear_command_log

    teardown = run_command(
      @workspace.join("bin/workspace-teardown"),
      chdir: @workspace,
      env: { "FAKE_HERDR_LIST" => malformed_list },
    )
    expect(teardown.status).not_to be_success
    expect(marker_path.read.strip).to eq("w99")
    expect(command_log.grep(/^docker\|/)).to be_empty
  end

  it "validates a marker before any destructive teardown" do
    marker_path.write("../../not-an-id\n")

    result = run_command(@workspace.join("bin/workspace-teardown"), chdir: @workspace)

    expect(result.status).not_to be_success
    expect(result.stderr).to include("invalid Herdr workspace marker")
    expect(command_log.grep(/docker/)).to be_empty
  end

  it "closes Herdr after Docker and Lewp and retains the marker on close failure" do
    setup = run_command(
      @workspace.join("bin/workspace-setup"),
      chdir: @workspace,
      env: { "HERDR_WORKSPACE_ID" => "w1" },
    )
    expect(setup.status).to be_success, setup.stderr
    clear_command_log
    list = active_list

    result = run_command(
      @workspace.join("bin/workspace-teardown"),
      chdir: @workspace,
      env: { "FAKE_HERDR_LIST" => list, "FAKE_HERDR_CLOSE_STATUS" => "1" },
    )

    expect(result.status).not_to be_success
    down = command_log.index { |line| line.include?("down --remove-orphans --volumes") }
    release = command_log.index { |line| line.include?("lewp") && line.include?("release --path") }
    close = command_log.index { |line| line.include?("herdr") && line.include?("workspace close w99") }
    expect(down).to be < release
    expect(release).to be < close
    expect(marker_path).to exist
  end
end
