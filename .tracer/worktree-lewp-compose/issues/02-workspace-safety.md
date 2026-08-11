# 02 — Protect workspace identity and destructive operations

**What to build:** Setup and teardown prove which checkout owns each generated identity and Compose project before changing resources, fail closed when isolation is uncertain, and leave recoverable state after partial failures.

**Blocked by:** 01 — Provision and tear down an isolated workspace

**Status:** ready-for-agent

- [ ] Workspace names accept only 1 to 63 lowercase ASCII letters, digits, and internal hyphens with alphanumeric endpoints.
- [ ] Invalid names fail before Git, Lewp, Docker, dependency, or database operations and provide a safe suggestion when one can be derived.
- [ ] Setup removes inherited generated identities that name another workspace before later failure points can leave unsafe teardown state.
- [ ] Setup and teardown inspect Compose ownership and refuse a same-named project owned by another physical checkout.
- [ ] Setup stops when Docker is unavailable or Compose services do not become healthy.
- [ ] Setup trusts the generated Mise environment and stops unless Mise resolves the exact leased PostgreSQL port.
- [ ] Destructive operations validate the recorded Compose and Lewp identities against the current linked worktree.
- [ ] A linked worktree with missing Compose settings may derive only its validated local Compose identity; missing Lewp identity skips release with a warning.
- [ ] Docker cleanup failure prevents Lewp release and later cleanup steps.
- [ ] Lewp release failure preserves any later integration state for retry.
- [ ] Partial setup leaves allocated resources available for inspection and retry rather than rolling back ambiguously.
- [ ] Error output identifies the failed safety check and provides concrete recovery guidance.
- [ ] RSpec covers stale identities, ownership collisions, Mise mismatch, missing configuration, malformed configuration, Docker failure, Lewp failure, and cleanup ordering through public command behavior.
