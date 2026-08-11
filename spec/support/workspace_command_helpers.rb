# frozen_string_literal: true

require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

module WorkspaceCommandHelpers
  PROJECT_ROOT = Pathname(__dir__).join("../..").expand_path

  CommandResult = Data.define(:stdout, :stderr, :status)

  def build_workspace_repository
    @sandbox = Pathname(Dir.mktmpdir("lewp-reader-workspace-spec-"))
    @repository = @sandbox.join("reader")
    @fake_bin = @sandbox.join("fake-bin")
    @command_log = @sandbox.join("commands.log")
    FileUtils.mkdir_p([ @repository, @fake_bin ])

    %w[
      .gitignore
      compose.workspace.yml
      bin/workspace-setup
      bin/workspace-teardown
      bin/worktree
      script/workspace-common.sh
    ].each do |relative|
      destination = @repository.join(relative)
      FileUtils.mkdir_p(destination.dirname)
      FileUtils.cp(PROJECT_ROOT.join(relative), destination)
    end

    write_executable(@repository.join("bin/rails"), <<~'BASH')
      #!/usr/bin/env bash
      printf 'rails|%s|RAILS_ENV=%s|%s\n' "$PWD" "${RAILS_ENV:-}" "$*" >> "$COMMAND_LOG"
      exit "${FAKE_RAILS_STATUS:-0}"
    BASH

    write_fake_tools
    git("init", "-b", "main")
    git("config", "user.email", "workspace-spec@example.test")
    git("config", "user.name", "Workspace Spec")
    git("add", ".")
    git("commit", "-m", "fixture")
  end

  def cleanup_workspace_repository
    FileUtils.remove_entry(@sandbox) if @sandbox&.exist?
  end

  def create_linked_workspace(name = "feed-fix")
    path = @repository.join(".worktrees", name)
    FileUtils.mkdir_p(path.dirname)
    git("worktree", "add", "-b", name, path.to_s)
    path
  end

  def run_command(path, *arguments, env: {}, chdir: path.dirname.dirname)
    stdout, stderr, status = Open3.capture3(workspace_env.merge(env), path.to_s, *arguments, chdir: chdir.to_s)
    CommandResult.new(stdout:, stderr:, status:)
  end

  def workspace_env
    {
      "PATH" => "#{@fake_bin}:#{ENV.fetch("PATH")}",
      "COMMAND_LOG" => @command_log.to_s,
      "HOME" => @sandbox.join("home").to_s,
      "WORKSPACE_ALLOW_UNSUPPORTED_OS" => "1",
      "HERDR_WORKSPACE_ID" => nil
    }
  end

  def command_log
    @command_log.exist? ? @command_log.read.lines.map(&:chomp) : []
  end

  def clear_command_log
    @command_log.write("")
  end

  def git(*arguments, chdir: @repository)
    stdout, stderr, status = Open3.capture3("git", *arguments, chdir: chdir.to_s)
    raise "git #{arguments.join(' ')} failed: #{stderr}" unless status.success?

    stdout
  end

  # PATH for simulating an environment without jq: the fake tools plus symlinks
  # to the real binaries setup needs before its jq guard, with the system PATH
  # (and therefore the real jq) excluded.
  def path_without_jq
    restricted = @sandbox.join("restricted-bin")
    unless restricted.exist?
      FileUtils.mkdir_p(restricted)
      %w[bash dirname basename git].each do |tool|
        real, status = Open3.capture2("which", tool)
        raise "could not resolve #{tool} for restricted PATH" unless status.success?

        File.symlink(real.strip, restricted.join(tool))
      end
    end
    "#{@fake_bin}:#{restricted}"
  end

  def install_fake_herdr
    write_executable(@fake_bin.join("herdr"), <<~'BASH')
      #!/usr/bin/env bash
      printf 'herdr|%s|%s\n' "$PWD" "$*" >> "$COMMAND_LOG"
      case "$1 $2" in
        "workspace list")
          if [ "${FAKE_HERDR_MALFORMED:-0}" = 1 ]; then
            printf 'not-json\n'
          elif [ -n "${FAKE_HERDR_LIST:-}" ]; then
            printf '%s\n' "$FAKE_HERDR_LIST"
          else
            printf '%s\n' '{"id":"list","result":{"type":"workspace_list","workspaces":[]}}'
          fi
          ;;
        "workspace create") printf '{"id":"create","result":{"workspace":{"workspace_id":"w99"}}}\n' ;;
        "workspace focus") exit "${FAKE_HERDR_FOCUS_STATUS:-0}" ;;
        "workspace close") exit "${FAKE_HERDR_CLOSE_STATUS:-0}" ;;
      esac
    BASH
  end

  private

  def write_fake_tools
    write_executable(@fake_bin.join("lewp"), <<~'BASH')
      #!/usr/bin/env bash
      printf 'lewp|%s|%s\n' "$PWD" "$*" >> "$COMMAND_LOG"
      case "$1" in
        init)
          host="${*: -1}"
          printf 'host = "%s"\n' "$host" > .lewp.local.toml
          ;;
        lease)
          host=""
          while [ "$#" -gt 0 ]; do [ "$1" = --host ] && { shift; host="$1"; }; shift || true; done
          printf '{"host":"%s","port":41000}\n' "$host"
          ;;
        port)
          case "$3" in vite) port=41001;; postgres) port=41002;; redis) port=41003;; *) exit 2;; esac
          printf '{"port":%s}\n' "$port"
          ;;
        release) exit "${FAKE_LEWP_RELEASE_STATUS:-0}" ;;
      esac
    BASH

    write_executable(@fake_bin.join("docker"), <<~'BASH')
      #!/usr/bin/env bash
      printf 'docker|%s|project=%s|pg=%s|redis=%s|checkout=%s|%s\n' \
        "$PWD" "${COMPOSE_PROJECT_NAME:-}" "${POSTGRES_PORT:-}" "${REDIS_PORT:-}" \
        "${LEWP_READER_CHECKOUT_PATH:-}" "$*" >> "$COMMAND_LOG"
      if [ "$1" = ps ]; then
        [ "${FAKE_DOCKER_PS_STATUS:-0}" = 0 ] || exit "$FAKE_DOCKER_PS_STATUS"
        printf '%s' "${FAKE_DOCKER_IDS:-}"
      elif [ "$1" = inspect ]; then
        printf '%s\n' "${FAKE_DOCKER_OWNER:-$PWD}"
      elif [ "$1" = compose ]; then
        case " $* " in
          *" version "*) exit 0 ;;
          *" up -d --wait "*) exit "${FAKE_DOCKER_UP_STATUS:-0}" ;;
          *" down --remove-orphans --volumes "*) exit "${FAKE_DOCKER_DOWN_STATUS:-0}" ;;
          *" exec -T postgres psql "*) printf '%s\n' "${FAKE_DATABASE_EXISTS:-}" ;;
        esac
      fi
    BASH

    write_executable(@fake_bin.join("mise"), <<~'BASH')
      #!/usr/bin/env bash
      printf 'mise|%s|%s\n' "$PWD" "$*" >> "$COMMAND_LOG"
      case "$1" in
        trust) exit "${FAKE_MISE_TRUST_STATUS:-0}" ;;
        env)
          port="${FAKE_MISE_PORT:-$(awk -F '"' '/^PGPORT =/ {print $2}' .mise.local.toml)}"
          printf '{"PGPORT":"%s"}\n' "$port"
          ;;
        exec)
          shift
          [ "${1:-}" = -- ] && shift
          exec "$@"
          ;;
      esac
    BASH

    write_executable(@fake_bin.join("bundle"), <<~'BASH')
      #!/usr/bin/env bash
      printf 'bundle|%s|%s\n' "$PWD" "$*" >> "$COMMAND_LOG"
      if [ "$1" = check ]; then exit "${FAKE_BUNDLE_CHECK_STATUS:-0}"; fi
      exit "${FAKE_BUNDLE_INSTALL_STATUS:-0}"
    BASH

    write_executable(@fake_bin.join("npm"), <<~'BASH')
      #!/usr/bin/env bash
      printf 'npm|%s|%s\n' "$PWD" "$*" >> "$COMMAND_LOG"
      if [ "$1" = ls ]; then
        [ -z "${FAKE_NPM_LS_STATUS:-}" ] || exit "$FAKE_NPM_LS_STATUS"
        [ -d node_modules ] && exit 0
        exit 1
      fi
      [ "$1" = ci ] && mkdir -p node_modules
      exit "${FAKE_NPM_STATUS:-0}"
    BASH
  end

  def write_executable(path, content)
    FileUtils.mkdir_p(path.dirname)
    path.write(content)
    path.chmod(0o755)
  end
end
