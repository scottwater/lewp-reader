# 01 — Provision and tear down an isolated workspace

**What to build:** A developer can provision a manually created linked worktree, run the application against Lewp-assigned ports and isolated Docker Compose services, preserve or reseed its data, and tear down its runtime resources without affecting the Git checkout.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] The default localhost workflow still uses local PostgreSQL on 5432, local Redis on 6379, and Rails on 3000 without requiring Lewp, Mise, or Docker.
- [ ] Workspace setup leases a routed Rails port plus named Vite, PostgreSQL, and Redis ports from Lewp.
- [ ] A linked worktree named `feed-fix` receives the hostname `feed-fix.reader.lewp`.
- [ ] Setup generates and trusts a local Mise environment containing the app host, all leased ports, the Compose identity, libpq settings, and Redis URL.
- [ ] PostgreSQL 17 and Redis 7 run in a workspace-specific Compose project, publish only to loopback, report healthy before setup continues, and use workspace-specific named volumes.
- [ ] PostgreSQL uses the fixed `postgres` role with local trust authentication.
- [ ] Rails, Vite, and Sidekiq remain host processes rather than Compose services.
- [ ] Rails database and development URL configuration consume workspace environment values while preserving localhost defaults.
- [ ] Vite consumes `VITE_PORT` and fails instead of selecting another port when the lease is unavailable.
- [ ] A new development database receives seeds once, repeated setup preserves its data, explicit reseeding resets only that workspace, and setup prepares the test database.
- [ ] Teardown removes the current workspace's containers, orphans, and named volumes, then releases its Lewp allocations.
- [ ] Teardown leaves the Git worktree in place for a separate removal command.
- [ ] Generated Lewp, Mise, seed, process-manager, and workspace runtime artifacts remain outside version control.
- [ ] RSpec exercises the public setup and teardown commands with controlled fake tools, and process-level checks cover Rails and Vite environment consumption.
