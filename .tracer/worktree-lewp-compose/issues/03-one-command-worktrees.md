# 03 — Create and resume Git worktrees with one command

**What to build:** A developer can create or resume a branch and linked checkout with one command, inherit approved local setup safely, install locked dependencies, provision the isolated workspace, and recover from interrupted provisioning.

**Blocked by:** 01 — Provision and tear down an isolated workspace; 02 — Protect workspace identity and destructive operations

**Status:** ready-for-agent

- [ ] The worktree command accepts a required workspace name and an optional Git start point.
- [ ] New branches start from committed HEAD by default or from the supplied start point.
- [ ] Existing branches can be checked out when they are not active elsewhere.
- [ ] Re-running the command resumes only an exact branch and checkout-path match.
- [ ] Conflicting destinations, branches checked out elsewhere, and start points supplied for existing branches fail without changing resources.
- [ ] Linked checkouts default to the git-ignored `.worktrees/<name>` location under the primary checkout.
- [ ] `WORKTREE_ROOT` supports an alternate absolute or primary-checkout-relative location.
- [ ] Destinations inside the repository must be ignored by Git.
- [ ] The command locates the primary checkout correctly when invoked from either the primary checkout or a linked worktree.
- [ ] The command warns when source-checkout changes are uncommitted because the new worktree starts from committed history.
- [ ] Existing approved local files are copied without overwriting destination files: Bundler configuration, the development environment file, the main credential key, and environment-specific credential keys.
- [ ] Copied environment files retain unrelated secrets but remove app host, app and Vite ports, database URL, libpq, Redis, and Compose values owned by workspace isolation.
- [ ] Missing Ruby and JavaScript dependencies install through their lockfiles before provisioning; direct workspace setup remains self-sufficient.
- [ ] Successful creation reports the checkout, Lewp URL, and next command.
- [ ] Failed provisioning leaves the worktree and partial resources intact and prints executable resume, teardown, and Git removal guidance.
- [ ] RSpec covers creation, explicit start points, existing branches, resumption, path conflicts, custom roots, ignored-path enforcement, dirty warnings, copied-file safety, dependency failures, and recovery output.
