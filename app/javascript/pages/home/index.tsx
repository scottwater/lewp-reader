import { Form, Link, usePage } from "@inertiajs/react"

import LewpBrand from "@/components/lewp-brand"
import LewpHead from "@/components/lewp-head"
import LewpLogo from "@/components/lewp-logo"
import { dashboard, demoSessions, sessions, users } from "@/routes"

export default function Home() {
  const { auth } = usePage().props

  return (
    <div className="marketing-page">
      <LewpHead title="A quiet place for your feeds" />

      <div className="marketing-container">
        <header className="marketing-header">
          <LewpBrand />
          <nav className="marketing-nav" aria-label="Account navigation">
            {auth.user ? (
              <Link className="text-link" href={dashboard.index()}>
                Open reader
              </Link>
            ) : (
              <>
                <Link className="text-link" href={sessions.new()}>
                  Log in
                </Link>
                <Link
                  className="paper-button paper-button-small"
                  href={users.new()}
                >
                  Sign up
                </Link>
              </>
            )}
          </nav>
        </header>

        <main>
          <section className="marketing-hero">
            <LewpLogo animated className="marketing-hero-logo" />
            <p className="marketing-kicker lewp-reveal">Lewp Reader</p>
            <h1 className="lewp-reveal">
              The good parts of the web, in order.
            </h1>
            <p className="marketing-lede lewp-reveal-delayed">
              A small, calm RSS reader for following people who still publish on
              their own patch of the internet. No algorithm. No infinite feed.
            </p>

            <div className="marketing-actions lewp-reveal-delayed">
              {auth.user ? (
                <Link className="paper-button" href={dashboard.index()}>
                  Open your reader <span aria-hidden="true">→</span>
                </Link>
              ) : (
                <>
                  <Link className="paper-button" href={users.new()}>
                    Make your reader <span aria-hidden="true">→</span>
                  </Link>
                  <Form action={demoSessions.create()}>
                    {({ processing }) => (
                      <button
                        className="quiet-button"
                        type="submit"
                        disabled={processing}
                      >
                        {processing ? "Opening demo…" : "Try the Lewp demo"}
                      </button>
                    )}
                  </Form>
                </>
              )}
            </div>
          </section>

          <section className="marketing-demo" aria-labelledby="demo-title">
            <div className="marketing-demo-copy">
              <h2 id="demo-title">Built for reading, not catching up.</h2>
              <p>
                New posts arrive in a simple list. Open one, read it, move on.
                The unread count is a reference—not a demand.
              </p>
            </div>

            <div
              className="terminal-object"
              aria-label="Lewp local demo command"
            >
              <div className="terminal-titlebar" aria-hidden="true">
                <span className="terminal-lights">
                  <i />
                  <i />
                  <i />
                </span>
                <span>~/src/lewp-reader</span>
              </div>
              <div className="terminal-body">
                <p>
                  <span className="terminal-prompt">$</span> lewp lease
                </p>
                <p className="terminal-muted">PORT=42137</p>
                <p className="terminal-muted">URL=http://lewp-reader.lewp</p>
                <p className="terminal-success">
                  HTTPS_URL=https://lewp-reader.lewp
                </p>
              </div>
            </div>
          </section>

          <section className="marketing-features" aria-label="Reader features">
            <article>
              <span className="feature-number">01</span>
              <div>
                <h2>Your subscriptions, nothing else.</h2>
                <p>RSS and Atom feeds from the writers and sites you choose.</p>
              </div>
            </article>
            <article>
              <span className="feature-number">02</span>
              <div>
                <h2>A list with an end.</h2>
                <p>
                  Read posts are quietly marked. Mark the rest when you are
                  done.
                </p>
              </div>
            </article>
            <article>
              <span className="feature-number">03</span>
              <div>
                <h2>A real Lewp workspace.</h2>
                <p>
                  This little app is the demo: Rails, React, jobs, and parallel
                  local development behind stable Lewp URLs.
                </p>
              </div>
            </article>
          </section>

          {!auth.user && (
            <section
              className="marketing-signup"
              aria-labelledby="signup-title"
            >
              <p className="marketing-kicker">Start here</p>
              <h2 id="signup-title">Bring back the web you picked.</h2>
              <p>Create an account, then add a feed—or start with ours.</p>
              <div className="marketing-actions">
                <Link className="paper-button" href={users.new()}>
                  Sign up for Lewp Reader <span aria-hidden="true">→</span>
                </Link>
                <Form action={demoSessions.create()}>
                  {({ processing }) => (
                    <button
                      className="quiet-button"
                      type="submit"
                      disabled={processing}
                    >
                      {processing ? "Opening demo…" : "Look around first"}
                    </button>
                  )}
                </Form>
              </div>
            </section>
          )}
        </main>

        <footer className="marketing-footer">
          <div className="footer-loop">
            <LewpLogo compact />
            <span>lo, and behold.</span>
          </div>
          <span>Lewp Reader · a small demo with a finite feed</span>
        </footer>
      </div>
    </div>
  )
}
