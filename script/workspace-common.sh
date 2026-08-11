#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_IDENTITY_FILE=".workspace-identity.json"
WORKSPACE_MISE_FILE=".mise.local.toml"
WORKSPACE_LEWP_FILE=".lewp.local.toml"
WORKSPACE_SEED_MARKER="tmp/workspace-seeded"
WORKSPACE_COMPOSE_FILE="compose.workspace.yml"
HERDR_MARKER_NAME="lewp-reader-herdr-workspace"

fail() {
  printf 'Error: %s\n' "$*" >&2
  return 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

validate_workspace_name() {
  local name="${1:-}"
  if [[ "$name" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
    return 0
  fi

  local suggestion
  suggestion="$(printf '%s' "$name" | tr '[:upper:]_' '[:lower:]-' | tr -cd 'a-z0-9-' | sed -E 's/-+/-/g; s/^-+//; s/-+$//' | cut -c1-63 | sed -E 's/-+$//')"
  printf 'Error: invalid workspace name %q. Use 1-63 lowercase letters, digits, or internal hyphens.\n' "$name" >&2
  if validate_workspace_name "$suggestion" 2>/dev/null && [ "$suggestion" != "$name" ]; then
    printf 'Safe suggestion: %s\n' "$suggestion" >&2
  fi
  return 1
}

physical_dir() {
  (cd "$1" >/dev/null 2>&1 && pwd -P)
}

checkout_root() {
  git rev-parse --show-toplevel
}

primary_checkout() {
  local common
  common="$(git rev-parse --path-format=absolute --git-common-dir)"
  physical_dir "$(dirname "$common")"
}

is_primary_checkout() {
  [ "$(physical_dir "$1")" = "$(primary_checkout)" ]
}

herdr_marker_path() {
  local git_dir
  git_dir="$(git rev-parse --path-format=absolute --git-dir)"
  printf '%s/%s\n' "$git_dir" "$HERDR_MARKER_NAME"
}

identity_value() {
  local file="$1" key="$2"
  jq -er --arg key "$key" '.[$key] | select(type == "string")' "$file"
}

validate_recorded_identity() {
  local file="$1" expected_name="$2" expected_mode="$3" expected_checkout="$4"
  jq -e 'type == "object"' "$file" >/dev/null 2>&1 || fail "generated identity is malformed: $file"

  local name mode checkout project host
  name="$(identity_value "$file" workspace_name)" || fail "generated identity has no valid workspace_name"
  mode="$(identity_value "$file" mode)" || fail "generated identity has no valid mode"
  checkout="$(identity_value "$file" checkout_path)" || fail "generated identity has no valid checkout_path"
  project="$(identity_value "$file" compose_project)" || fail "generated identity has no valid compose_project"
  host="$(identity_value "$file" app_host)" || fail "generated identity has no valid app_host"

  [ "$name" = "$expected_name" ] || fail "generated identity belongs to workspace '$name', not '$expected_name'"
  [ "$mode" = "$expected_mode" ] || fail "generated identity mode '$mode' does not match '$expected_mode'"
  [ "$checkout" = "$expected_checkout" ] || fail "generated identity belongs to another checkout: $checkout"
  [ "$project" = "lewp-reader-$expected_name" ] || fail "unexpected Compose identity: $project"

  if [ "$expected_mode" = main ]; then
    [ "$host" = reader.lewp ] || fail "main workspace identity has unexpected host: $host"
  else
    [ "$host" = "$expected_name.reader.lewp" ] || fail "linked workspace identity has unexpected host: $host"
  fi
}

compose() {
  docker compose -f "$WORKSPACE_COMPOSE_FILE" -p "$1" "${@:2}"
}

assert_compose_owned_or_empty() {
  local project="$1" checkout="$2"
  local ids id owner

  ids="$(docker ps -aq --filter "label=com.docker.compose.project=$project")" || fail "Docker is unavailable while checking Compose ownership"
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    owner="$(docker inspect -f '{{ index .Config.Labels "com.lewp-reader.checkout" }}' "$id")" || fail "could not inspect Compose ownership for $project"
    if [ -z "$owner" ] || [ "$owner" = "<no value>" ]; then
      owner="$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' "$id")" || fail "could not inspect Compose ownership for $project"
    fi
    [ "$owner" = "$checkout" ] || fail "Compose project $project is owned by another checkout: $owner"
  done <<EOF
$ids
EOF

  ids="$(docker volume ls -q --filter "label=com.docker.compose.project=$project")" || fail "Docker volumes could not be inspected"
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    owner="$(docker volume inspect -f '{{ index .Labels "com.lewp-reader.checkout" }}' "$id")" || fail "could not inspect Compose volume ownership for $project"
    [ "$owner" = "$checkout" ] || fail "Compose project $project has a volume owned by another checkout: ${owner:-unknown}"
  done <<EOF
$ids
EOF

  ids="$(docker network ls -q --filter "label=com.docker.compose.project=$project")" || fail "Docker networks could not be inspected"
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    owner="$(docker network inspect -f '{{ index .Labels "com.lewp-reader.checkout" }}' "$id")" || fail "could not inspect Compose network ownership for $project"
    [ "$owner" = "$checkout" ] || fail "Compose project $project has a network owned by another checkout: ${owner:-unknown}"
  done <<EOF
$ids
EOF
}

validate_herdr_list_json() {
  printf '%s' "$1" | jq -e '
    (.result.workspaces | type) == "array" and
    all(.result.workspaces[];
      ((.workspace_id | type) == "string") and
      (.workspace_id | test("^w[[:alnum:]]+$")) and
      ((has("worktree") | not) or
        (((.worktree | type) == "object") and
         ((.worktree.checkout_path | type) == "string"))))
  ' >/dev/null 2>&1
}

require_workspace_tools() {
  local tool
  for tool in lewp jq mise docker; do
    command_exists "$tool" || fail "required workspace tool is missing: $tool"
  done
  docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 is unavailable"
}

print_recovery() {
  local root="$1"
  printf '\nRecovery commands:\n' >&2
  printf '  cd %q && bin/workspace-setup\n' "$root" >&2
  printf '  cd %q && bin/workspace-teardown\n' "$root" >&2
  if ! is_primary_checkout "$root" 2>/dev/null; then
    printf '  git -C %q worktree remove %q\n' "$(primary_checkout)" "$root" >&2
  fi
}
