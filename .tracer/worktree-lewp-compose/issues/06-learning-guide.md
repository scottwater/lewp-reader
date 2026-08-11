# 06 — Publish the worktree and Lewp learning guide

**What to build:** A developer can follow one learning-oriented README from basic localhost startup through isolated Lewp worktrees, then consult a separate Stooges addendum for exact hypothetical adaptation guidance without confusing it with supported repository behavior.

**Blocked by:** 03 — Create and resume Git worktrees with one command; 04 — Run the primary checkout through reader.lewp; 05 — Integrate optional Herdr workspace lifecycle

**Status:** ready-for-agent

- [ ] The README describes the project as a minimal working RSS and Atom reader used to demonstrate an isolated worktree pattern.
- [ ] Basic setup appears first and covers local Ruby and Node versions, local PostgreSQL and Redis, dependency installation, database preparation, seeds, startup, and `localhost:3000` verification.
- [ ] The guide states that the worktree pattern applies beyond Ruby and explains workspace identity, Lewp leases, generated Mise environment, isolated Compose services, and explicit teardown.
- [ ] Workspace requirements reflect current macOS support and explain Git worktrees, Lewp setup with the default `.lewp` suffix, jq, activated Mise, and a Docker Compose v2 runtime.
- [ ] OrbStack is the recommended macOS runtime and Docker Desktop appears as an alternative; scripts remain runtime-neutral.
- [ ] The Mise section explains why shell activation matters, how silent fallback can reach shared services, and how to verify a leased value before running development or test commands.
- [ ] The README documents optional main-checkout provisioning at `reader.lewp` while preserving localhost as the intended default.
- [ ] Daily-use examples cover new worktrees, explicit start points, custom roots, resumption, startup, seed preservation, explicit reseeding, teardown, and separate Git removal.
- [ ] The guide explains Rails, Vite, PostgreSQL, and Redis port allocation, generated files, Compose project identity, volumes, credential copying, and environment sanitization.
- [ ] Troubleshooting covers invalid names, dirty source changes, missing Mise activation, Docker failures, inherited identities, ownership collisions, partial provisioning, missing generated files, and Herdr failures.
- [ ] DSLR appears only as an optional snapshot approach for slow, complex, or shared seed preparation and is not presented as a requirement.
- [ ] The implementation and documentation contain no organization-specific names, domains, or assumptions.
- [ ] A separate Stooges addendum contains clearly labeled hypothetical metadata, executable setup and teardown wrappers, `STOOGES_FOLDER_PATH` handling, delegation to workspace commands, conditional Herdr notes, `stooges trash` behavior, and safety constraints.
- [ ] The Stooges addendum includes a copyable prompt that asks an agent to adapt and validate the hypothetical integration against the current Stooges version.
- [ ] No working Stooges configuration, hook installation, or runtime dependency is added to the repository.
- [ ] Documented commands are checked against the implemented interfaces and the final manual smoke-test procedure covers localhost, main Lewp mode, two concurrent worktrees, isolated data, reseeding, teardown, and route release.
