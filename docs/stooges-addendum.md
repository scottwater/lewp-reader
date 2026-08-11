# Hypothetical Stooges adaptation

> **Not supported configuration:** this addendum is implementation guidance, not installed Stooges integration. The repository contains no Stooges hooks, runtime dependency, or working metadata changes. Validate all fields and hook semantics against the Stooges version you intend to use.

The checked-in lifecycle exposes `bin/workspace-setup` and `bin/workspace-teardown`. A future Stooges adapter should remain a thin caller of those commands rather than duplicating Lewp, Compose, Mise, database, ownership, or Herdr logic.

## Hypothetical metadata

After running the current Stooges initialization command, preserve its required fields and add hook paths like these:

```json
{
  "mainBranch": "main",
  "managedWorkspaces": ["feed-fix"],
  "setupScript": ".stooges/bin/reader-workspace-setup.sh",
  "teardownScript": ".stooges/bin/reader-workspace-teardown.sh"
}
```

The paths and `.stooges-metadata.json` shape above were checked against Stooges 0.86. This repository does not include them. Recheck them against the installed version before adaptation.

## Hypothetical executable wrappers

Setup wrapper:

```bash
#!/usr/bin/env bash
set -euo pipefail

workspace_path="${STOOGES_FOLDER_PATH:?Stooges must provide an absolute workspace path}"
[ -d "$workspace_path" ] || { echo "missing Stooges workspace: $workspace_path" >&2; exit 1; }
cd "$workspace_path"

# Adaptation prerequisite: the lifecycle must recognize this Stooges checkout
# as a linked workspace and bind its validated STOOGES_FOLDER identity. Do not
# pass --main or infer reader.lewp for every independent clone.
exec bin/workspace-setup
```

Teardown wrapper:

```bash
#!/usr/bin/env bash
set -euo pipefail

workspace_path="${STOOGES_FOLDER_PATH:?Stooges must provide an absolute workspace path}"
[ -d "$workspace_path" ] || { echo "missing Stooges workspace: $workspace_path" >&2; exit 1; }
cd "$workspace_path"
exec bin/workspace-teardown
```

Make wrappers executable in the future integration. Use `STOOGES_FOLDER_PATH`, not a guessed `main/<name>` layout. If the installed version also provides `STOOGES_FOLDER`, validate it with the same lowercase hostname/Compose-name rules and prove that it matches the physical checkout basename before allowing destructive operations.

## Required adaptation before enabling hooks

Stooges versions that create independent clones do not share the Git common directory used by this repository to distinguish a primary checkout from a linked worktree. Therefore, the wrappers above must **not** be enabled unchanged. First adapt the public lifecycle with a narrowly scoped, tested Stooges identity input that:

1. Is accepted only when the Stooges hook contract proves `STOOGES_FOLDER_PATH` is the current physical checkout.
2. Validates the workspace name before Lewp, Docker, dependencies, or databases.
3. Records the physical checkout, Compose project, hostname, and leases in the same generated identity used by teardown.
4. Never maps a managed Stooges workspace to the primary-only `reader.lewp` / `lewp-reader-main` identity.
5. Preserves Compose ownership inspection, Mise `PGPORT` verification, seed-once behavior, cleanup ordering, and partial-failure recovery.
6. Calls the checked-in setup/teardown implementation rather than reimplementing its destructive logic in hook wrappers.

## Herdr and trash behavior

The lifecycle's Herdr integration is already conditional. A Stooges hook launched with both `herdr` and an active `HERDR_WORKSPACE_ID` may create/focus a checkout workspace; hooks outside Herdr should skip silently. Teardown must close only the Git-dir marker it validated, after Docker and Lewp cleanup.

In the known Stooges command contract, `stooges trash <workspace>` preflights removal, runs `teardownScript`, and then moves the checkout to system trash. Without a trash utility, `--force` may permanently delete it. Do not use forced trash to bypass teardown failure: doing so can strand containers, volumes, leases, or a Herdr marker after deleting the only trustworthy checkout identity. Keep Git/check-out removal after successful runtime teardown.

## Safety constraints

- Never source arbitrary workspace environment files as shell code.
- Never overwrite a copied credential during resume or replace an identity proved to belong to another checkout; regenerating the current checkout's own identity is expected.
- Never derive a destructive main identity from a missing file.
- Never release Lewp after failed Docker cleanup.
- Never close Herdr after failed Docker or Lewp cleanup.
- Never make setup rollback a partially allocated workspace ambiguously.
- Test hooks through disposable Stooges workspaces with fake Lewp, Docker, Mise, jq, and Herdr boundaries before touching developer data.

## Copyable agent prompt

```text
Adapt this repository's checked-in bin/workspace-setup and bin/workspace-teardown
for the currently installed Stooges release. First read that release's official
hook and metadata documentation and record its exact version. Do not install or
enable hooks until tests pass.

Use STOOGES_FOLDER_PATH as the authoritative candidate checkout path and validate
its physical path against the hook working directory. If STOOGES_FOLDER is
available, validate it with the repository's 1-63 lowercase alphanumeric/hyphen
workspace-name rule and prove it matches the checkout identity. Add the smallest
public lifecycle input needed for independent Stooges clones; never route them as
--main. Thin wrappers must delegate to the checked-in lifecycle rather than copy
Lewp, Mise, Compose, database, or Herdr cleanup logic.

Preserve these invariants: generated identity owns destructive operations;
Compose labels must match the physical checkout; Mise must resolve the exact
leased PGPORT; seed only a new database unless explicit reseed; Docker cleanup
precedes Lewp release; Lewp release precedes Herdr close; failed cleanup retains
recoverable markers/resources; Git or Stooges trash remains separate.

Add command-level tests with fake external tools for setup, teardown, malformed
or inherited identities, ownership collisions, partial failures, conditional
Herdr, and trash ordering. Verify the exact current .stooges-metadata.json fields,
hook environment, setup-failure behavior, and stooges trash/--force semantics.
Show the proposed metadata and wrapper diff for approval before enabling it.
```
