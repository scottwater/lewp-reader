# frozen_string_literal: true

require "spec_helper"
require_relative "../support/workspace_command_helpers"

RSpec.describe "bin/worktree" do
  include WorkspaceCommandHelpers

  before { build_workspace_repository }
  after { cleanup_workspace_repository }

  it "rejects unsafe names before Git or infrastructure changes" do
    result = run_command(@repository.join("bin/worktree"), "Bad_Name", chdir: @repository)

    expect(result.status).not_to be_success
    expect(result.stderr).to include("invalid workspace name", "Safe suggestion: bad-name")
    expect(git("branch", "--list", "Bad_Name")).to be_empty
    expect(command_log).to be_empty
  end

  it "creates, provisions, copies approved files, and sanitizes environment values" do
    FileUtils.mkdir_p(@repository.join("config/credentials"))
    @repository.join(".env.development").write(<<~ENV)
      SECRET_TOKEN=keep-me
      PORT=3000
      export VITE_PORT=5173
      APP_HOST=wrong.reader.lewp
      PGPORT=5432
      PGHOSTADDR=192.0.2.1
      REDIS_URL=redis://localhost:6379/0
      COMPOSE_PROJECT_NAME=wrong
    ENV
    @repository.join("config/master.key").write("master-secret")
    @repository.join("config/credentials/development.key").write("development-secret")

    result = run_command(@repository.join("bin/worktree"), "feed-fix", chdir: @repository)

    expect(result.status).to be_success
    target = @repository.join(".worktrees/feed-fix")
    expect(target).to be_directory
    expect(git("branch", "--show-current", chdir: target).strip).to eq("feed-fix")
    expect(target.join("config/master.key").read).to eq("master-secret")
    expect(target.join("config/credentials/development.key").read).to eq("development-secret")
    copied_env = target.join(".env.development").read
    expect(copied_env).to include("SECRET_TOKEN=keep-me")
    expect(copied_env).not_to match(/PORT=|APP_HOST=|PGPORT=|PGHOSTADDR=|REDIS_URL=|COMPOSE_PROJECT_NAME=/)
    expect(target.join(".workspace-identity.json")).to exist
    expect(result.stdout).to include("https://feed-fix.reader.lewp")
  end

  it "resumes only an exact destination and branch match" do
    first = run_command(@repository.join("bin/worktree"), "feed-fix", chdir: @repository)
    expect(first.status).to be_success
    clear_command_log

    second = run_command(@repository.join("bin/worktree"), "feed-fix", chdir: @repository, env: { "FAKE_DATABASE_EXISTS" => "1" })

    expect(second.status).to be_success
    expect(second.stdout).to include("Resuming exact worktree match")
    expect(git("worktree", "list", "--porcelain").scan(/^worktree /).length).to eq(2)
  end

  it "warns about dirty source changes and installs missing dependencies from locks" do
    @repository.join("dirty.txt").write("dirty")

    result = run_command(
      @repository.join("bin/worktree"),
      "dependency-check",
      chdir: @repository,
      env: { "FAKE_BUNDLE_CHECK_STATUS" => "1" },
    )

    expect(result.status).to be_success
    expect(result.stderr).to include("uncommitted changes")
    expect(command_log.grep(/^bundle\|/).join("\n")).to include("check", "install")
    expect(command_log.grep(/^npm\|/).join).to include("ci")
  end

  it "rejects a branch checked out at another destination" do
    elsewhere = @sandbox.join("elsewhere")
    git("worktree", "add", "-b", "busy", elsewhere.to_s)

    result = run_command(@repository.join("bin/worktree"), "busy", chdir: @repository)

    expect(result.status).not_to be_success
    expect(result.stderr).to include("already checked out at")
    expect(command_log).to be_empty
  end

  it "does not overwrite approved files when exact setup resumes" do
    first = run_command(@repository.join("bin/worktree"), "keep-local", chdir: @repository)
    expect(first.status).to be_success
    target = @repository.join(".worktrees/keep-local")
    target.join(".env.development").write("LOCAL_ONLY=preserve\n")
    @repository.join(".env.development").write("SOURCE_CHANGED=yes\n")

    second = run_command(
      @repository.join("bin/worktree"),
      "keep-local",
      chdir: @repository,
      env: { "FAKE_DATABASE_EXISTS" => "1" },
    )

    expect(second.status).to be_success
    expect(target.join(".env.development").read).to eq("LOCAL_ONLY=preserve\n")
  end

  it "starts from the invoking linked checkout's committed HEAD" do
    caller = create_linked_workspace("caller")
    caller.join("caller-commit.txt").write("from caller")
    git("add", "caller-commit.txt", chdir: caller)
    git("commit", "-m", "caller commit", chdir: caller)
    caller_head = git("rev-parse", "HEAD", chdir: caller).strip

    result = run_command(caller.join("bin/worktree"), "from-caller", chdir: caller)

    expect(result.status).to be_success
    expect(git("rev-parse", "from-caller").strip).to eq(caller_head)
    expect(@repository.join(".worktrees/from-caller/caller-commit.txt")).to exist
  end

  it "supports an explicit start point for a new branch" do
    base = git("rev-parse", "HEAD").strip

    result = run_command(@repository.join("bin/worktree"), "from-base", base, chdir: @repository)

    expect(result.status).to be_success
    expect(git("rev-parse", "from-base").strip).to eq(base)
  end

  it "checks out an existing branch that is not active elsewhere" do
    git("branch", "existing-ready")

    result = run_command(@repository.join("bin/worktree"), "existing-ready", chdir: @repository)

    expect(result.status).to be_success
    target = @repository.join(".worktrees/existing-ready")
    expect(git("branch", "--show-current", chdir: target).strip).to eq("existing-ready")
  end

  it "supports an external custom worktree root" do
    external_root = @sandbox.join("external-worktrees")

    result = run_command(
      @repository.join("bin/worktree"),
      "external",
      chdir: @repository,
      env: { "WORKTREE_ROOT" => external_root.to_s },
    )

    expect(result.status).to be_success
    expect(external_root.join("external")).to be_directory
  end

  it "rejects a conflicting destination without provisioning" do
    conflict = @repository.join(".worktrees/conflict")
    FileUtils.mkdir_p(conflict)
    conflict.join("keep.txt").write("do not touch")
    clear_command_log

    result = run_command(@repository.join("bin/worktree"), "conflict", chdir: @repository)

    expect(result.status).not_to be_success
    expect(result.stderr).to include("destination exists")
    expect(conflict.join("keep.txt").read).to eq("do not touch")
    expect(command_log).to be_empty
  end

  it "rejects a start point for an existing branch without provisioning" do
    git("branch", "existing")
    clear_command_log

    result = run_command(@repository.join("bin/worktree"), "existing", "HEAD", chdir: @repository)

    expect(result.status).not_to be_success
    expect(result.stderr).to include("cannot be supplied for existing branch")
    expect(command_log).to be_empty
  end

  it "requires custom destinations inside the repository to be ignored" do
    result = run_command(
      @repository.join("bin/worktree"),
      "unsafe-root",
      chdir: @repository,
      env: { "WORKTREE_ROOT" => "checkouts" },
    )

    expect(result.status).not_to be_success
    expect(result.stderr).to include("must be ignored by Git")
    expect(@repository.join("checkouts/unsafe-root")).not_to exist
  end

  it "keeps a failed checkout and prints executable recovery commands" do
    result = run_command(
      @repository.join("bin/worktree"),
      "retry-me",
      chdir: @repository,
      env: { "FAKE_MISE_PORT" => "5432" },
    )

    target = @repository.join(".worktrees/retry-me")
    expect(result.status).not_to be_success
    expect(target).to be_directory
    expect(result.stderr).to include("bin/workspace-setup", "bin/workspace-teardown", "git -C")
  end
end
