# 04 — Run the primary checkout through reader.lewp

**What to build:** A developer can opt the primary checkout into the isolated workspace lifecycle at `reader.lewp` while keeping the conventional localhost workflow as the default and protecting the primary checkout's special identity during teardown.

**Blocked by:** 01 — Provision and tear down an isolated workspace; 02 — Protect workspace identity and destructive operations

**Status:** ready-for-agent

- [ ] Conventional setup remains the documented default and does not invoke Lewp, Mise, Docker, or workspace setup.
- [ ] Explicit main-workspace mode leases `reader.lewp` rather than deriving a hostname from the checkout directory.
- [ ] Main-workspace mode receives separate Rails, Vite, PostgreSQL, and Redis ports and a dedicated `lewp-reader-main` Compose project.
- [ ] Main-workspace setup uses the same health checks, generated Mise environment, seed-once behavior, explicit reseeding, and test preparation as linked worktrees.
- [ ] Application URLs and host authorization use `reader.lewp` while main-workspace mode is active and return to localhost defaults without its environment.
- [ ] Teardown validates the recorded main identity before deleting Compose data or releasing Lewp.
- [ ] Teardown refuses to infer the primary checkout's special identity when generated configuration is missing or incomplete.
- [ ] Main-workspace teardown leaves the primary Git checkout untouched.
- [ ] RSpec covers localhost independence, explicit main provisioning, the special hostname and Compose identity, reseeding, successful teardown, and missing or inherited main identity failures.
