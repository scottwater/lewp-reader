import { Form, Link, usePage } from "@inertiajs/react"

import LewpBrand from "@/components/lewp-brand"
import LewpFieldError from "@/components/lewp-field-error"
import LewpHead from "@/components/lewp-head"
import {
  dashboard,
  entries as entryRoutes,
  feeds as feedRoutes,
  reader as readerRoutes,
  sessions,
} from "@/routes"

interface Feed {
  id: number
  title: string
  url: string
  site_url: string | null
  unread_count: number
  entry_count: number
  status: string
  last_fetched_at: string | null
  fetch_error: string | null
}

interface Entry {
  id: number
  title: string
  url: string | null
  author: string | null
  published_at: string | null
  summary: string | null
  read: boolean
  feed: Pick<Feed, "id" | "title">
}

interface SelectedEntry extends Omit<Entry, "summary" | "url"> {
  content_html?: string
  summary?: string | null
  url: string | null
}

interface ReaderProps {
  feeds: Feed[]
  entries: Entry[]
  selected_feed: Feed | null
  selected_entry: SelectedEntry | null
  pagination: {
    page: number
    has_newer: boolean
    has_older: boolean
  }
}

function formatDate(value: string | null) {
  if (!value) return "No date"

  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return "No date"

  return new Intl.DateTimeFormat(undefined, {
    day: "numeric",
    month: "short",
    year:
      date.getFullYear() === new Date().getFullYear() ? undefined : "numeric",
  }).format(date)
}

function feedStatus(feed: Feed) {
  if (feed.fetch_error) return "Needs attention"
  if (feed.status === "refreshing" || feed.status === "queued")
    return "Updating"
  if (!feed.last_fetched_at) return "Waiting for first update"
  return `Updated ${formatDate(feed.last_fetched_at)}`
}

export default function Reader({
  feeds,
  entries,
  selected_feed: selectedFeed,
  selected_entry: selectedEntry,
  pagination,
}: ReaderProps) {
  const { auth } = usePage().props
  const unreadTotal = feeds.reduce((sum, feed) => sum + feed.unread_count, 0)
  const listTitle = selectedFeed?.title ?? "All entries"
  const listPageRoute = (page: number) =>
    selectedFeed
      ? feedRoutes.show(selectedFeed.id, { query: { page } })
      : dashboard.index({ query: { page } })

  return (
    <div className="reader-page">
      <LewpHead title={selectedEntry?.title ?? listTitle} />

      <header className="reader-header">
        <LewpBrand suffix="reader" />
        <div className="reader-account">
          <span className="reader-account-name">{auth.user.name}</span>
          <Link
            as="button"
            className="mono-link"
            href={sessions.destroy(auth.session.id)}
          >
            Log out
          </Link>
        </div>
      </header>

      <main
        className={`reader-workspace ${selectedEntry ? "has-selected-entry" : ""}`}
      >
        <aside className="feed-pane" aria-labelledby="feeds-heading">
          <div className="pane-heading feed-pane-heading">
            <div>
              <p className="pane-label">Subscriptions</p>
              <h1 id="feeds-heading">Feeds</h1>
            </div>
            <span className="mono-count">{feeds.length}</span>
          </div>

          <nav className="feed-nav" aria-label="Feeds">
            <Link
              className={`feed-row ${selectedFeed ? "" : "is-selected"}`}
              href={dashboard.index()}
            >
              <span>
                <strong>All entries</strong>
                <small>{feeds.length} subscriptions</small>
              </span>
              {unreadTotal > 0 && <b>{unreadTotal}</b>}
            </Link>

            {feeds.map((feed) => (
              <Link
                key={feed.id}
                className={`feed-row ${selectedFeed?.id === feed.id ? "is-selected" : ""}`}
                href={feedRoutes.show(feed.id)}
              >
                <span>
                  <strong>{feed.title}</strong>
                  <small>{feedStatus(feed)}</small>
                </span>
                {feed.unread_count > 0 && <b>{feed.unread_count}</b>}
              </Link>
            ))}
          </nav>

          {feeds.length === 0 && (
            <p className="feed-empty">
              Add your first feed below. RSS or Atom works.
            </p>
          )}

          {selectedFeed && (
            <section
              className="feed-tools"
              aria-label={`${selectedFeed.title} actions`}
            >
              <p className="pane-label">Selected feed</p>
              {selectedFeed.fetch_error && (
                <p className="feed-error" role="status">
                  {selectedFeed.fetch_error}
                </p>
              )}
              <div className="feed-tool-actions">
                <Form action={feedRoutes.refresh(selectedFeed.id)}>
                  {({ processing }) => (
                    <button
                      className="mono-link"
                      type="submit"
                      disabled={processing}
                    >
                      {processing ? "Queuing…" : "Refresh"}
                    </button>
                  )}
                </Form>
                {selectedFeed.unread_count > 0 && (
                  <Form action={feedRoutes.markAllRead(selectedFeed.id)}>
                    {({ processing }) => (
                      <button
                        className="mono-link"
                        type="submit"
                        disabled={processing}
                      >
                        Mark all read
                      </button>
                    )}
                  </Form>
                )}
                <Form action={feedRoutes.destroy(selectedFeed.id)}>
                  {({ processing }) => (
                    <button
                      className="mono-link danger-link"
                      type="submit"
                      disabled={processing}
                    >
                      Remove
                    </button>
                  )}
                </Form>
              </div>
            </section>
          )}

          <Form
            action={feedRoutes.create()}
            resetOnSuccess
            className="add-feed-form"
          >
            {({ processing, errors }) => (
              <>
                <label htmlFor="feed-url">Add a feed</label>
                <div className="add-feed-controls">
                  <input
                    id="feed-url"
                    name="url"
                    type="url"
                    required
                    disabled={processing}
                    inputMode="url"
                    placeholder="https://example.com/feed.xml"
                    aria-describedby={errors.url ? "feed-url-error" : undefined}
                  />
                  <button
                    type="submit"
                    disabled={processing}
                    aria-label="Add feed"
                  >
                    {processing ? "…" : "+"}
                  </button>
                </div>
                <span id="feed-url-error">
                  <LewpFieldError messages={errors.url} />
                </span>
              </>
            )}
          </Form>
        </aside>

        <section className="entry-list-pane" aria-labelledby="entries-heading">
          <div className="pane-heading entry-list-heading">
            <div>
              <p className="pane-label">Newest first</p>
              <h2 id="entries-heading">{listTitle}</h2>
            </div>
            {unreadTotal > 0 && !selectedFeed && (
              <Form action={readerRoutes.markAllRead()}>
                {({ processing }) => (
                  <button
                    className="mono-link"
                    type="submit"
                    disabled={processing}
                  >
                    Mark all read
                  </button>
                )}
              </Form>
            )}
          </div>

          <div className="entry-list">
            {entries.map((entry) => (
              <Link
                key={entry.id}
                as="button"
                className={`entry-row ${entry.read ? "is-read" : ""} ${
                  selectedEntry?.id === entry.id ? "is-selected" : ""
                }`}
                href={entryRoutes.update(entry.id, {
                  query: {
                    scope: selectedFeed ? "feed" : "all",
                    page: pagination.page,
                  },
                })}
              >
                <span className="entry-row-topline">
                  <span className="entry-feed-name">{entry.feed.title}</span>
                  <time dateTime={entry.published_at ?? undefined}>
                    {formatDate(entry.published_at)}
                  </time>
                </span>
                <strong>{entry.title}</strong>
                <span className="entry-author">
                  {entry.author ? `By ${entry.author}` : "From the feed"}
                </span>
              </Link>
            ))}

            {entries.length === 0 && (
              <div className="list-empty">
                <p className="empty-loop" aria-hidden="true">
                  ↝
                </p>
                <h3>Nothing waiting here.</h3>
                <p>
                  {feeds.length === 0
                    ? "Add a feed and its latest entries will arrive here."
                    : "This feed is quiet for now. Try a refresh or another feed."}
                </p>
              </div>
            )}
          </div>

          <nav className="entry-pagination" aria-label="Entry pages">
            <span className="entry-pagination-action">
              {pagination.has_newer && (
                <Link
                  className="mono-link"
                  href={listPageRoute(pagination.page - 1)}
                >
                  <span aria-hidden="true">←</span> Newer
                </Link>
              )}
            </span>
            <span className="entry-pagination-page">
              Page {pagination.page}
            </span>
            <span className="entry-pagination-action entry-pagination-older">
              {pagination.has_older && (
                <Link
                  className="mono-link"
                  href={listPageRoute(pagination.page + 1)}
                >
                  Older <span aria-hidden="true">→</span>
                </Link>
              )}
            </span>
          </nav>
        </section>

        <article className="entry-detail-pane" aria-live="polite">
          {selectedEntry ? (
            <div className="entry-detail">
              <Link
                className="entry-mobile-back"
                href={listPageRoute(pagination.page)}
              >
                <span aria-hidden="true">←</span> Back to entries
              </Link>
              <div className="entry-detail-meta">
                <Link href={feedRoutes.show(selectedEntry.feed.id)}>
                  {selectedEntry.feed.title}
                </Link>
                <span aria-hidden="true">·</span>
                <time dateTime={selectedEntry.published_at ?? undefined}>
                  {formatDate(selectedEntry.published_at)}
                </time>
              </div>
              <h2>{selectedEntry.title}</h2>
              {selectedEntry.author && (
                <p className="entry-byline">By {selectedEntry.author}</p>
              )}
              {selectedEntry.content_html ? (
                <div
                  className="entry-content"
                  dangerouslySetInnerHTML={{
                    __html: selectedEntry.content_html,
                  }}
                />
              ) : (
                <div className="entry-content">
                  <p>
                    {selectedEntry.summary ??
                      "This post does not include a summary."}
                  </p>
                </div>
              )}
              {selectedEntry.url && (
                <a
                  className="paper-button read-original"
                  href={selectedEntry.url}
                  target="_blank"
                  rel="noreferrer"
                >
                  Read on the original site <span aria-hidden="true">↗</span>
                </a>
              )}
            </div>
          ) : (
            <div className="detail-empty">
              <span className="detail-empty-mark" aria-hidden="true">
                ↝
              </span>
              <h2>Pick something to read.</h2>
              <p>
                Open an entry from the list. It will be marked read as you go.
              </p>
            </div>
          )}
        </article>
      </main>
    </div>
  )
}
