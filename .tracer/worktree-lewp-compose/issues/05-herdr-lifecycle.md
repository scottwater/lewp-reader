# 05 — Integrate optional Herdr workspace lifecycle

**What to build:** Developers working inside Herdr receive a checkout-specific Herdr workspace that setup can create or focus and teardown can close safely. Developers outside Herdr use the same workspace commands without added requirements.

**Blocked by:** 01 — Provision and tear down an isolated workspace; 02 — Protect workspace identity and destructive operations

**Status:** ready-for-agent

- [ ] Herdr integration runs only when the `herdr` executable exists and the caller has an active Herdr workspace context.
- [ ] Missing Herdr, or installed Herdr without active context, causes a silent skip rather than setup failure.
- [ ] Provisioning creates and focuses a Herdr workspace for the checkout after core workspace setup succeeds.
- [ ] Provisioning stores the validated Herdr workspace identifier in the checkout's Git directory rather than its working tree.
- [ ] Repeated provisioning focuses an active recorded workspace instead of creating a duplicate.
- [ ] A stale marker is removed only after the recorded workspace is confirmed inactive, then provisioning creates a replacement.
- [ ] Invalid marker paths, malformed identifiers, malformed JSON, unexpected response schemas, command failures, and marker-write failures produce safe recovery guidance.
- [ ] Teardown validates any Herdr marker and required tooling before destructive operations begin.
- [ ] Teardown closes Herdr only after Docker cleanup and Lewp release succeed.
- [ ] Teardown closes only the recorded active workspace and removes the marker after success or when the workspace is already absent.
- [ ] Failed Herdr closure retains the marker for retry without undoing completed Docker or Lewp cleanup.
- [ ] RSpec covers conditional activation, creation, focus, stale markers, malformed responses, orphan guidance, cleanup ordering, successful closure, and retryable closure failure.
