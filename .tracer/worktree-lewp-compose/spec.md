## Problem Statement

Developers need to run this example application in parallel Git worktrees without sharing application ports, Vite ports, databases, Redis data, or process state. The current setup assumes one checkout using Rails on port 3000, Vite on its default port, PostgreSQL on 5432, and Redis on 6379. A second checkout can collide with the first or modify the same development and test data.

The repository also needs to teach the isolation pattern without burying it in application-specific machinery. A developer should be able to verify the minimal reader on localhost first, then adopt Lewp, Mise, Docker Compose, and worktrees as a separate workflow. The documentation must explain why Mise activation matters and how setup and teardown protect one workspace from another.

## Solution

Keep the existing localhost workflow as the default. A developer with local PostgreSQL and Redis can run the application at `http://localhost:3000` without Lewp, Mise, or Docker.

Add a Bash-based workspace lifecycle for the primary checkout and Git worktrees. Lewp assigns stable Rails, Vite, PostgreSQL, and Redis ports. Each worktree receives a hostname shaped as `<workspace>.reader.lewp`; the primary checkout can opt into `reader.lewp`. Mise loads generated environment variables in each checkout. Docker Compose runs isolated PostgreSQL and Redis services with workspace-owned volumes while Rails, Vite, and Sidekiq continue to run on the host.

Provide a worktree command that creates or resumes a branch and checkout, copies approved local files, installs dependencies, provisions the isolated services, seeds a new database, and registers with Herdr when the developer invokes it from an active Herdr context. Provide a separate teardown command that removes runtime resources without removing the Git worktree.

Rewrite the README as a self-contained guide to the minimal app and the transferable isolation pattern. Publish a Stooges addendum with hypothetical configuration and agent instructions, but do not add Stooges integration to the working implementation.

## User Stories

1. As a developer evaluating the example, I want to run it at `localhost:3000`, so that I can verify the app before learning the workspace tooling.
2. As a developer using the default setup, I want to use local PostgreSQL and Redis, so that Lewp, Mise, and Docker remain optional.
3. As a developer, I want the README to identify the app as a minimal RSS and Atom reader, so that I understand its role as a useful demonstration workload.
4. As a developer, I want the README to list the basic app setup steps first, so that infrastructure details do not block my first run.
5. As a developer, I want the README to describe the worktree pattern as framework agnostic, so that I can apply it outside Rails projects.
6. As a developer, I want to opt the primary checkout into Lewp, so that I can test the routed environment before creating another worktree.
7. As a developer using Lewp for the primary checkout, I want to open `reader.lewp`, so that the main environment has a short URL.
8. As a developer, I want to create a branch and worktree with one command, so that I do not have to coordinate Git and runtime provisioning by hand.
9. As a developer, I want a worktree named `feed-fix` to use `feed-fix.reader.lewp`, so that the URL identifies its branch.
10. As a developer, I want worktrees to live under a git-ignored directory by default, so that repository status remains clean.
11. As a developer, I want to override the worktree root, so that I can keep checkouts elsewhere on disk.
12. As a developer, I want workspace names validated before Git or infrastructure changes occur, so that branch names also produce safe hostnames and Compose identities.
13. As a developer, I want the command to warn when my source checkout has uncommitted changes, so that I know the new worktree starts from committed history.
14. As a developer, I want to create a worktree from an explicit start point, so that I can branch from a remote branch or selected commit.
15. As a developer, I want to resume an exact branch and worktree match, so that interrupted provisioning can be retried safely.
16. As a developer, I want the command to reject ambiguous branch or checkout reuse, so that it does not provision the wrong directory.
17. As a developer, I want each workspace to receive a stable Rails port, so that parallel servers do not collide.
18. As a developer, I want each workspace to receive a stable Vite port, so that HMR and asset serving do not collide.
19. As a developer, I want Vite to fail when its assigned port is unavailable, so that it does not move to an undocumented port.
20. As a developer, I want each workspace to receive isolated PostgreSQL and Redis ports, so that application processes connect to their own containers.
21. As a developer, I want each workspace to use its own Compose project and volumes, so that database resets and Redis data cannot affect another workspace.
22. As a developer, I want Rails, Vite, and Sidekiq to run on my host, so that the example demonstrates service isolation without becoming a development-container example.
23. As a developer, I want generated environment settings to take effect when I enter a workspace, so that normal commands use the leased services.
24. As a developer, I want setup to fail when Mise does not resolve the leased environment, so that commands do not fall back to shared local services.
25. As a developer, I want the README to explain that installing Mise is insufficient without shell activation, so that I do not unknowingly use port 5432 from a worktree.
26. As a developer, I want a command that confirms the active leased environment, so that I can diagnose Mise activation before starting the app.
27. As a developer, I want setup to remove generated identity inherited from another checkout, so that clone or copy operations cannot retain another workspace's ownership.
28. As a developer, I want setup to refuse a Compose project owned by another physical checkout, so that duplicate names cannot overwrite another workspace's containers or volumes.
29. As a developer, I want teardown to validate recorded identities before deleting resources, so that stale configuration cannot target another workspace.
30. As a developer, I want the primary checkout's teardown to require its generated identity, so that the special `reader.lewp` mapping cannot be inferred incorrectly.
31. As a developer, I want setup to preserve an existing workspace database, so that rerunning provisioning does not erase my work.
32. As a developer, I want a new development database seeded once, so that the demo account and starter feeds are ready without repeated seed work.
33. As a developer, I want an explicit reseed option, so that I can reset only the current workspace's development data.
34. As a developer, I want setup to prepare the test database, so that tests work when provisioning completes.
35. As a developer, I want teardown to delete the current workspace's database and Redis volumes, so that disposable workspaces leave no service data behind.
36. As a developer, I want teardown to release Lewp only after Docker cleanup succeeds, so that failed cleanup leaves a route I can use while recovering.
37. As a developer, I want Git worktree removal to remain a separate command, so that infrastructure cleanup succeeds before Git deletes the checkout.
38. As a developer, I want setup failures to print resume, teardown, and removal commands, so that I can recover without reconstructing paths.
39. As a developer, I want approved local credentials and configuration copied into a new worktree, so that it can start without repetitive secret setup.
40. As a developer, I want copied files to leave existing worktree files untouched, so that resuming setup does not overwrite local changes.
41. As a developer, I want copied environment files stripped of workspace-owned connection values, so that secrets carry over without ports or database URLs leaking across worktrees.
42. As a developer, I want missing Ruby and JavaScript dependencies installed through locked dependency definitions, so that a new worktree can start promptly.
43. As a developer using another worktree manager, I want workspace setup to work when called directly, so that Git creation and runtime provisioning remain separate interfaces.
44. As a Herdr user, I want provisioning to create or focus a matching Herdr workspace when I launch it from Herdr, so that terminal navigation follows the checkout.
45. As a developer outside Herdr, I want provisioning to skip Herdr without warnings or failures, so that Herdr remains optional.
46. As a Herdr user, I want teardown to close only the workspace recorded for the checkout, so that it cannot close an unrelated Herdr workspace.
47. As a Herdr user, I want teardown to retain the Herdr marker when close fails, so that I can retry cleanup safely.
48. As a developer, I want generated mailer URLs and development host authorization to follow the active app host, so that localhost and Lewp routes both work.
49. As a developer, I want the README to show daily creation, startup, reseeding, teardown, and removal commands, so that I can use the workflow without reading source code.
50. As a developer, I want troubleshooting guidance for Mise, Docker, naming, inherited settings, and failed provisioning, so that common failures have concrete recovery steps.
51. As a developer with expensive seed preparation, I want the README to mention database snapshots as an optional extension, so that I know when a tool such as DSLR may help.
52. As a developer considering Stooges, I want a separate addendum with hypothetical setup and teardown wiring, so that the core worktree example stays focused.
53. As a developer delegating Stooges adoption, I want a copyable agent prompt and exact example configuration, so that an agent can adapt the workspace lifecycle without guessing at safety requirements.
54. As a maintainer, I want the shell orchestration tested through its public commands, so that refactors cannot break user-visible lifecycle behavior.
55. As a maintainer, I want Rails and Vite environment consumption tested at process boundaries, so that generated ports and hosts reach the application.

## Implementation Decisions

- Preserve the default local workflow. It expects PostgreSQL on port 5432 and Redis on port 6379, starts Rails at `localhost:3000`, and does not require Lewp, Mise, or Docker.
- Add an explicit main-workspace mode. It maps the primary checkout to `reader.lewp`, leases isolated ports, starts Compose services, and uses the same generated environment as linked worktrees.
- Implement orchestration in Bash to keep the pattern independent of Ruby. Application-specific dependency and database commands remain replaceable adaptation points.
- Expose three public command interfaces: create or resume a Git worktree, provision the current workspace, and tear down the current workspace.
- The worktree creation interface accepts a required workspace name and an optional Git start point.
- The workspace provisioning interface accepts main-workspace mode and an optional reseed operation. Linked worktrees derive identity from their validated checkout basename.
- Use 1 to 63 lowercase ASCII letters, digits, and internal hyphens for worktree names. Require an alphanumeric first and last character.
- Use the workspace name as the Git branch, checkout basename, Lewp hostname prefix, and Compose identity suffix. The primary checkout uses the special identity `main` for Compose and the special hostname `reader.lewp`.
- Place linked checkouts under `.worktrees/<name>` by default. Support a generic `WORKTREE_ROOT` override and require any destination inside the repository to be ignored by Git.
- Create a new branch when one does not exist. Resume only when the destination and checked-out branch form an exact match. Reject conflicting paths, branches checked out elsewhere, and start points supplied for existing branches.
- Warn that uncommitted source changes do not appear in a worktree created from committed history.
- Lease one routed Lewp port for Rails and named bare ports for Vite, PostgreSQL, and Redis. Use `<workspace>.reader.lewp` for linked worktrees.
- Export the Vite lease through `VITE_PORT`. Configure Vite to use that port with strict port selection. The browser reaches Rails through the Lewp hostname and reaches Vite through its leased loopback port.
- Export the app route through `APP_HOST` and the Rails port through `PORT`. Development URL generation and host authorization consume these values while retaining localhost defaults.
- Generate local Lewp identity and Mise environment files in each provisioned checkout. Keep generated files out of Git.
- Generate generic environment names where possible: `PORT`, `VITE_PORT`, `APP_HOST`, `COMPOSE_PROJECT_NAME`, `POSTGRES_PORT`, `REDIS_PORT`, libpq variables, and `REDIS_URL`.
- Require Mise only for the isolated workspace workflow. Setup trusts the generated local configuration and verifies that Mise resolves the leased PostgreSQL port before reporting success.
- Keep the existing Ruby and Node version files as runtime declarations. Do not add Mise tool-version management.
- Run PostgreSQL 17 and Redis 7 in Docker Compose. Bind leased ports to loopback only.
- Use a fixed PostgreSQL `postgres` role with trust authentication inside the local-only Compose service.
- Give each workspace its own Compose project and named PostgreSQL and Redis volumes. Compose project names use `lewp-reader-<workspace>`.
- Keep Rails, Vite, and Sidekiq on the host. The existing production container build remains separate from workspace provisioning.
- Before setup or teardown, inspect Compose ownership labels. Refuse to operate when the same Compose identity belongs to another physical checkout.
- Remove inherited generated identity files when they name another workspace before continuing setup. Treat generated identity as the authority for destructive operations.
- If a linked worktree lacks generated Compose settings during teardown, derive its validated identity and target only that Compose project. Skip Lewp release when Lewp identity is absent. Do not infer the primary checkout's special identity when its generated configuration is missing.
- Start Compose services and wait for healthy PostgreSQL and Redis before preparing the application.
- Seed only a newly created isolated development database. Preserve development data when setup runs again.
- Support explicit reseeding that resets and seeds only the current workspace's development database. Prepare the test database after development setup.
- Delete containers, orphaned resources, and named volumes during teardown. Release Lewp only after Docker cleanup succeeds.
- Keep Git worktree removal separate from workspace teardown. Print the appropriate removal command after provisioning failures and in documentation.
- Copy existing local files from an allowlist without overwriting destination files. The allowlist covers Bundler configuration, the local development environment file, the main Rails credential key, and environment-specific credential keys.
- Sanitize copied environment files by removing values owned by workspace isolation, including application and Vite ports, app host, database URLs, libpq variables, Redis URL, and Compose settings. Preserve unrelated secrets.
- Install missing Ruby dependencies through Bundler's locked resolution. Install JavaScript dependencies through the npm lockfile. Both worktree creation and direct workspace provisioning must leave a checkout ready to run.
- Leave partial worktrees and allocated resources in place after provisioning failure. Print executable resume, teardown, and worktree-removal guidance.
- Integrate Herdr only when the executable exists and the caller has an active Herdr workspace context. Provisioning outside that condition skips Herdr.
- When Herdr integration applies, create or focus the checkout's Herdr workspace and store the returned validated identifier in the worktree's Git directory rather than the checkout.
- On teardown, validate the Herdr marker before destructive work. Close the recorded Herdr workspace only after Docker cleanup and Lewp release. Retain the marker when closure fails so the developer can retry.
- Add `.worktrees/`, generated Lewp and Mise files, process-manager sockets, seed markers, and other workspace runtime artifacts to Git ignores.
- Keep the README self-contained for app setup and worktree operations. Explain the minimal app, localhost setup, worktree motivation, macOS requirements, Lewp setup, Mise shell activation, optional main routing, daily commands, generated environment, Vite behavior, reseeding, teardown, and troubleshooting.
- State that Lewp currently limits the supported workspace workflow to macOS. Require a Docker Compose v2-compatible runtime; recommend OrbStack and mention Docker Desktop as an alternative without coupling scripts to either.
- Mention DSLR only as an optional snapshot approach for projects whose seeds are slow, complex, or need a shared starting database. Do not integrate DSLR.
- Publish a separate Stooges addendum. Include hypothetical metadata, executable wrapper examples, `STOOGES_FOLDER_PATH` handling, delegation to the checked-in workspace lifecycle, conditional Herdr considerations, trash behavior, safety constraints, and a copyable agent prompt. Do not install Stooges files or hooks.
- Remove all organization-specific names, domains, and assumptions from the adapted implementation and documentation.

## Testing Decisions

- Test user-visible behavior rather than Bash function structure. A useful test invokes a public command, controls its environment, and asserts status, output, filesystem effects, or external command interactions.
- Use RSpec as the test runner because the repository already depends on it. The orchestration remains Bash-based.
- Use one primary orchestration seam: invoke public workspace commands inside temporary Git repositories with a controlled `PATH` containing fake Lewp, Docker, Mise, jq, Herdr, Bundler, npm, and Rails executables.
- Build shared test helpers for temporary primary checkouts, linked worktrees, executable fakes, captured command logs, generated identities, and simulated failures.
- Cover workspace-name acceptance, rejection, and safe suggestions.
- Cover new branch creation, explicit start points, existing branch checkout, exact-match resumption, conflicting destinations, branches checked out elsewhere, custom roots, ignored-path enforcement, and dirty-checkout warnings.
- Cover approved local-file copying, no-overwrite behavior, credential glob handling, and sanitization of workspace-owned environment values.
- Cover dependency success, dependency installation fallback, lockfile-based npm installation, direct provisioning, and recovery output after failure.
- Cover Lewp host and port allocation for linked worktrees and the primary checkout. Assert that generated configuration contains the leased Rails, Vite, PostgreSQL, and Redis values.
- Cover Mise trust failures and resolved-environment mismatches. Setup must stop before application preparation when Mise cannot prove isolation.
- Cover stale generated identities, same-named Compose projects owned by other directories, Docker daemon failures, service health failures, and partial allocation failures.
- Cover first-time database preparation and seeding, repeat setup without reseeding, explicit reseeding, test database preparation, and nonzero application preparation results.
- Cover teardown identity validation, ownership refusal, missing linked-worktree configuration, missing primary configuration, Docker failure ordering, Lewp release failure, volume deletion, and separate Git removal.
- Cover Herdr absence, installed Herdr without active context, active-context creation, existing-marker focus, stale-marker replacement, malformed responses, marker write failures, teardown closure, and retained markers after failure.
- Add process-level configuration checks for application defaults and generated environment consumption. Verify Rails database connectivity settings, app host behavior, and URL generation with and without workspace variables.
- Add a configuration-level Vite check that verifies `VITE_PORT` and strict port behavior. Retain the existing TypeScript, lint, and formatting commands as supporting validation.
- Use the reference application's command-level workspace specs as prior art for fake-command orchestration, ownership checks, failure ordering, and Herdr safety. Follow this repository's existing RSpec configuration and support-helper conventions.
- Do not require live Lewp, Docker, Mise, or Herdr for the automated test suite. Run a documented manual smoke test with those tools before declaring the integration complete.
- The manual smoke test must cover localhost startup, optional `reader.lewp` startup, two simultaneous worktrees, distinct Rails and Vite ports, isolated development data, repeat setup, reseeding, teardown, and route release.

## Out of Scope

- Stooges installation, checked-in Stooges hooks, or a supported Stooges runtime integration.
- DSLR installation, snapshot creation, snapshot restoration, or shared seed databases.
- Linux or Windows support for the Lewp workspace workflow.
- Containerizing Rails, Vite, Sidekiq, or the full development environment.
- Changes to production deployment or the production container image.
- New RSS reader product features, schema changes, or UI changes.
- Replacing the existing process manager selection.
- Using Mise to install or pin Ruby and Node.
- Automatic Git worktree deletion during teardown.
- Copying arbitrary unapproved files into new worktrees.
- Running Herdr when the executable is absent or the caller lacks active Herdr context.

## Further Notes

The repository has no configured issue tracker, so this specification lives in the local tracer feature directory.

The README should distinguish machine requirements from workflow requirements. Ruby, Node, local PostgreSQL, and local Redis support the basic localhost path. Lewp, activated Mise, jq, Git worktrees, and a Docker Compose v2 runtime support isolated workspaces.

Mise protects interactive commands only when the user's shell activation hook runs. Setup can trust the local file and inspect `mise env`, but it cannot force a later shell to apply the environment. Documentation must tell the developer to verify a leased value, such as `PGPORT`, from inside the checkout before running Rails or tests.

The Stooges addendum describes a future adaptation against the implemented public workspace commands. It must identify hypothetical content as guidance rather than repository-supported configuration.
