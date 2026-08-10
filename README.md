# Lewp Reader

A deliberately small, working RSS and Atom reader built to demonstrate Rails, Inertia.js, React, PostgreSQL, Redis, and Sidekiq in a Lewp-managed development workflow.

Lewp/Stooges/worktree orchestration is intentionally outside this repository. This app is the useful demo workload those tools can run later.

## What it does

- Sign up, sign in, sign out, or enter the seeded demo in one click
- Subscribe to RSS or Atom feed URLs
- Read a combined timeline or one feed at a time
- Mark an entry read when it is opened
- Mark one feed—or the whole reader—as read
- Refresh one feed on demand
- Refresh every subscribed feed hourly through Sidekiq
- Seed five starter feeds without making the test suite depend on the network

## Requirements

- Ruby and Node versions from `.ruby-version` and `.node-version`
- PostgreSQL running on `localhost:5432`
- Redis running on `localhost:6379`

On macOS with Homebrew, make sure your installed PostgreSQL and Redis services are started before setup.

## Run it

```sh
bin/setup
```

Setup installs dependencies, creates the PostgreSQL database, seeds the demo account and starter feeds, then starts Rails, Vite, and Sidekiq together. Open [http://localhost:3000](http://localhost:3000).

To prepare without starting processes:

```sh
bin/setup --skip-server
bin/dev
```

The seeded demo is available from the home page. Its underlying credentials are `demo@lewpreader.test` / `lewp-reader-demo`, although the UI signs in without asking for them.

## Useful commands

```sh
bin/rspec
npm run check
npm run lint
npm run format
bin/rubocop
bin/rails db:seed
```

Feed refresh jobs use `REDIS_URL` when set and otherwise use Sidekiq's local Redis default. Production database configuration uses `DATABASE_URL`.

## Seed feeds

- `https://andycroll.com/index.xml`
- `https://seths.blog/feed/`
- `https://island94.org/feed.xml`
- `https://evilmartians.com/chronicles.atom`
- `https://scottw.com/feed.xml`

## License

[MIT](LICENSE)
