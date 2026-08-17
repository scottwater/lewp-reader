# Lewp Reader

Lewp Reader is a small, working RSS and Atom reader. It also demonstrates a framework-agnostic pattern: give every Git worktree its own hostname, ports, databases, Redis data, and process environment.

## Run the reader locally first

The ordinary localhost workflow is the default. It does **not** require Lewp, Mise, or Docker.

### Requirements

- Ruby and Node versions from `.ruby-version` and `.node-version`
- PostgreSQL on `localhost:5432`
- Redis on `localhost:6379`

Install dependencies, prepare and seed the database, and start Rails, Vite, and Sidekiq:

```sh
bin/setup
```

Open <http://localhost:3000>. To prepare without starting processes:

```sh
bin/setup --skip-server
bin/dev
```

The home page can sign into the seeded demo directly. Its credentials are `demo@lewpreader.test` / `lewp-reader-demo`.

Useful checks:

```sh
bin/rspec
npm run check
npm run lint
npm run format
bin/rubocop
```

## What the app does

- Reads RSS and Atom feeds in a combined or per-feed timeline
- Tracks read entries and supports per-feed and global “mark read” actions
- Refreshes feeds on demand and hourly through host-side Sidekiq
- Seeds a demo account and five starter feeds without network-dependent tests

## Why isolate worktrees?

Two checkouts using Rails 3000, Vite's default port, PostgreSQL 5432, Redis 6379, and the same databases are not independent. This repository's optional workspace lifecycle gives each checkout:

1. A validated workspace identity derived from its branch/check-out basename.
2. A Lewp hostname and stable Rails, Vite, PostgreSQL, and Redis leases.
3. A generated Mise environment that normal host commands consume.
4. A dedicated Docker Compose project and named PostgreSQL/Redis volumes.
5. Explicit teardown before separate Git worktree removal.

Only PostgreSQL and Redis run in Compose. Rails, Vite, and Sidekiq stay on the host. The orchestration is Bash and its application preparation commands are intended adaptation points, so the pattern is not specific to Rails.

## Isolated workspace requirements (macOS)

Lewp currently makes this workflow macOS-only. Install:

- Git with worktree support
- Lewp, configured with its default `.lewp` suffix (`lewp setup && lewp system start`)
- `jq`
- [Mise](https://mise.jdx.dev/) **with shell activation enabled**
- A Docker Compose v2-compatible runtime

OrbStack is recommended on macOS; Docker Desktop is an alternative. The scripts call the runtime-neutral `docker compose` interface.

### Mise activation is a safety boundary

Installing Mise is not enough. Its shell activation hook applies `.mise.local.toml` when you enter a checkout. Without activation, an interactive `bin/rails`, test, or console command can silently fall back to shared PostgreSQL on 5432 or shared Redis on 6379.

After entering any isolated checkout, verify the lease before starting application commands:

```sh
mise env --json | jq -r .PGPORT
printf '%s\n' "$PGPORT"
```

Both should show the generated, non-default leased port. Setup trusts the generated file and checks Mise's resolved `PGPORT`, but it cannot activate a later shell for you.

## Optional primary checkout at `reader.lewp`

Keep localhost as the normal first-run path. To opt the primary checkout into the isolated lifecycle:

```sh
bin/workspace-setup --main
bin/dev
```

Open <https://reader.lewp>. This uses Compose project `lewp-reader-main` and isolated volumes. Rerunning setup preserves its development database. To reset only this workspace:

```sh
bin/workspace-setup --main --reseed
```

Teardown reads the generated main identity; it refuses to guess the special target when that identity is missing:

```sh
bin/workspace-teardown
```

## Create or resume a worktree

Workspace names are 1–63 lowercase ASCII letters, digits, and internal hyphens, with an alphanumeric first and last character.

```sh
# Branch from committed HEAD into .worktrees/feed-fix
bin/worktree feed-fix

# Branch from an explicit commit or remote branch
bin/worktree feed-fix origin/main

# Put linked checkouts somewhere else (absolute or primary-relative)
WORKTREE_ROOT=../reader-worktrees bin/worktree feed-fix
```

The default `.worktrees/` root is Git-ignored. An override located inside the repository must also be ignored. The command can be run from the primary checkout or a linked worktree and always locates the primary checkout through Git metadata.

If the branch does not exist, the command creates it. If it does exist and is not checked out, it checks it out. A rerun resumes only when destination and branch are an exact match. Conflicting paths, branches active elsewhere, and a start point supplied for an existing branch are rejected.

Uncommitted source changes trigger a warning because a new worktree starts from committed history. The command copies only approved local files and never overwrites destination files:

- `.bundle/config`
- `.env.development`
- `config/master.key`
- `config/credentials/*.key`

A copied `.env.development` retains unrelated secrets but removes workspace-owned host, port, database/libpq, Redis, and Compose values. Ruby dependencies use the bundle lock; JavaScript dependencies use `npm ci` and `package-lock.json`.

A successful `feed-fix` workspace opens at <https://feed-fix.reader.lewp>. Start host processes after entering it:

```sh
cd .worktrees/feed-fix
mise env --json | jq -r .PGPORT
bin/dev
```

## Provision, preserve, reseed, and tear down

`bin/workspace-setup` also works directly inside a manually created linked worktree:

```sh
bin/workspace-setup            # repeat-safe; preserves development data
bin/workspace-setup --reseed   # resets/seeds only this development database
```

Setup leases four stable ports, waits for PostgreSQL 17 and Redis 7 health checks, seeds a newly created development database once, and always prepares the test database. It writes:

- `.lewp.local.toml`: checkout-specific Lewp identity
- `.mise.local.toml`: `PORT`, `VITE_PORT`, `APP_HOST`, Compose, libpq, and Redis settings
- `.workspace-identity.json`: authority used for safety checks and teardown
- `tmp/workspace-seeded` and process/runtime files

Compose project names are `lewp-reader-<workspace>`. PostgreSQL and Redis bind leased ports to loopback and use project-owned named volumes. Vite consumes `VITE_PORT` with strict port selection; it fails rather than moving to an undocumented port.

Teardown deletes containers, orphans, and volumes, then releases Lewp. Docker failure prevents route release. Remove the Git worktree separately:

```sh
cd .worktrees/feed-fix
bin/workspace-teardown
cd ../..
git worktree remove .worktrees/feed-fix
```

When provisioning fails, partial resources and the checkout remain for diagnosis. The command prints executable resume, teardown, and Git removal commands.

## Optional Herdr behavior

When setup is launched with both a `herdr` executable and an active `HERDR_WORKSPACE_ID`, it creates or focuses a checkout-specific Herdr workspace after core provisioning succeeds. Its validated identifier is stored beside that checkout's Git metadata, not in the working tree. Outside an active Herdr context, integration is silently skipped.

Teardown validates the marker before destructive work, then closes only the recorded Herdr workspace after Docker cleanup and Lewp release. A close failure retains the marker so teardown can be retried safely.

## Troubleshooting

- **Invalid name:** use the safe suggestion printed by `bin/worktree`; uppercase, underscores, leading/trailing hyphens, and names over 63 characters are rejected before changes.
- **Dirty source warning:** commit the required changes first. Uncommitted content cannot appear in a worktree created from Git history.
- **Mise mismatch or shared port 5432:** enable Mise's shell activation, leave/re-enter the directory, run `mise trust`, and compare `mise env --json | jq -r .PGPORT` with `.workspace-identity.json`.
- **Docker unavailable or unhealthy:** start the Compose v2 runtime, inspect `docker compose -p lewp-reader-<name> -f compose.workspace.yml ps`, then rerun setup.
- **Inherited identity:** setup removes generated identity from another copied checkout. If teardown reports malformed or mismatched identity, do not edit it to force cleanup; inspect the named path and Compose project before choosing a recovery command.
- **Ownership collision:** another physical checkout owns the Compose project name. Use a unique workspace name or tear down the actual owning checkout. The scripts refuse to take it over.
- **Partial provisioning:** follow the printed resume/teardown/removal commands. Resources are not ambiguously rolled back.
- **Missing generated files:** linked teardown may derive only its validated local Compose name and skips Lewp release with a warning. Main teardown fails closed because `reader.lewp` must not be inferred.
- **Herdr failure:** inspect `herdr workspace list`. A retained Git-dir marker identifies the only workspace teardown may close; retry after fixing Herdr rather than deleting arbitrary workspaces.

For projects where seeds are slow, complex, or need a shared starting database, a snapshot tool such as DSLR can be an optional extension. It is not installed or integrated here.

## Manual smoke-test procedure

Automated specs use fake external tools. Before declaring a local integration operational, run this macOS smoke test:

1. Start the ordinary local services, run `bin/setup --skip-server && bin/dev`, and verify `localhost:3000`.
2. Provision the primary with `bin/workspace-setup --main`, verify `reader.lewp`, then record Rails/Vite/PG/Redis leases.
3. Create two differently named worktrees and run `bin/dev` in both; verify distinct Rails and Vite ports and routes.
4. Create different application data in each workspace and prove it is not visible in the others.
5. Rerun setup and prove data remains; run `--reseed` in one and prove only that workspace resets.
6. Teardown each linked checkout, verify its volumes are gone and route released, then remove its Git worktree separately.
7. Teardown the primary and verify `reader.lewp` is released while localhost remains usable.

See [docs/stooges-addendum.md](docs/stooges-addendum.md) for clearly hypothetical guidance on adapting these public commands to Stooges.

## Acknowledgments

Lewp Reader began as a fork of the [Inertia Rails React Starter Kit](https://github.com/inertia-rails/react-starter-kit). Thanks to Svyatoslav Kryukov and the Inertia Rails contributors for the foundation they provided. See the [Inertia Rails starter kits guide](https://inertia-rails.dev/guide/starter-kits) for more information.

## License

Lewp Reader is available under the [MIT License](LICENSE). The license retains the original starter kit's copyright notice alongside Lewp Reader's.
