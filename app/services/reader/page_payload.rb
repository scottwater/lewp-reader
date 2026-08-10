# frozen_string_literal: true

require "nokogiri"
require "set"
require "uri"

module Reader
  class PagePayload
    ENTRY_LIMIT = 100
    MAX_PAGE = ((2**63 - 1) / ENTRY_LIMIT) + 1
    CONTENT_TAGS = %w[p br h1 h2 h3 h4 blockquote pre code ul ol li strong em a img figure figcaption].freeze
    CONTENT_ATTRIBUTES = %w[href src alt title].freeze

    def initialize(user:, selected_feed: nil, selected_entry: nil, page: 1)
      @user = user
      @selected_feed = selected_feed
      @selected_entry = selected_entry
      @page = page
    end

    def as_json
      {
        feeds: serialized_feeds,
        entries: serialized_entries,
        selected_feed: selected_feed && serialize_feed(selected_feed),
        selected_entry: selected_entry && serialize_selected_entry(selected_entry),
        pagination: {
          page: page,
          has_newer: page > 1,
          has_older: entry_page.size > ENTRY_LIMIT
        }
      }
    end

    private

    attr_reader :user, :selected_feed, :selected_entry, :page

    def feeds
      @feeds ||= user.feeds.order(Arel.sql("LOWER(feeds.title) ASC")).to_a
    end

    def feed_ids
      @feed_ids ||= feeds.map(&:id)
    end

    def entry_counts
      @entry_counts ||= Entry.where(feed_id: feed_ids).group(:feed_id).count
    end

    def read_counts
      @read_counts ||= EntryRead.joins(:entry)
        .where(user: user, entries: { feed_id: feed_ids })
        .group("entries.feed_id")
        .count
    end

    def read_entry_ids
      @read_entry_ids ||= user.entry_reads.where(entry_id: page_entries.map(&:id)).pluck(:entry_id).to_set
    end

    def entry_scope
      scope = Entry.where(feed_id: selected_feed ? selected_feed.id : feed_ids)
      scope.includes(:feed)
        .order(Arel.sql("published_at DESC NULLS LAST, entries.created_at DESC, entries.id DESC"))
        .offset((page - 1) * ENTRY_LIMIT)
        .limit(ENTRY_LIMIT + 1)
    end

    def entry_page
      @entry_page ||= entry_scope.to_a
    end

    def page_entries
      @page_entries ||= entry_page.first(ENTRY_LIMIT)
    end

    def serialized_feeds
      feeds.map { |feed| serialize_feed(feed) }
    end

    def serialize_feed(feed)
      count = entry_counts.fetch(feed.id, 0)
      {
        id: feed.id,
        title: feed.title,
        url: feed.url,
        site_url: feed.site_url,
        unread_count: count - read_counts.fetch(feed.id, 0),
        entry_count: count,
        status: feed.status,
        last_fetched_at: feed.last_fetched_at&.iso8601,
        fetch_error: feed.fetch_error
      }
    end

    def serialized_entries
      page_entries.map do |entry|
        {
          id: entry.id,
          title: entry.title,
          url: entry.url,
          author: entry.author,
          published_at: entry.published_at&.iso8601,
          summary: plain_text(entry.summary.presence || entry.content),
          read: read_entry_ids.include?(entry.id),
          feed: { id: entry.feed_id, title: entry.feed.title }
        }
      end
    end

    def serialize_selected_entry(entry)
      {
        id: entry.id,
        title: entry.title,
        url: entry.url,
        author: entry.author,
        published_at: entry.published_at&.iso8601,
        read: user.entry_reads.exists?(entry: entry),
        feed: { id: entry.feed_id, title: entry.feed.title },
        content_html: sanitized_html(
          entry.content.presence || entry.summary,
          base_url: article_base_url(entry)
        )
      }
    end

    def helpers
      @helpers ||= ActionController::Base.helpers
    end

    def plain_text(html)
      helpers.truncate(helpers.strip_tags(html.to_s).squish, length: 240)
    end

    def sanitized_html(html, base_url: nil)
      sanitized = helpers.sanitize(html.to_s, tags: CONTENT_TAGS, attributes: CONTENT_ATTRIBUTES)
      return sanitized unless base_url

      fragment = Nokogiri::HTML::DocumentFragment.parse(sanitized)
      fragment.css("[href], [src]").each do |node|
        %w[href src].each do |attribute|
          next unless node.key?(attribute)

          node[attribute] = absolute_article_url(node[attribute], base_url)
        end
      end

      helpers.sanitize(fragment.to_html, tags: CONTENT_TAGS, attributes: CONTENT_ATTRIBUTES)
    end

    def article_base_url(entry)
      [ entry.url, entry.feed.site_url ].filter_map { |url| http_uri(url) }.first
    end

    def absolute_article_url(value, base_url)
      reference = URI.parse(value)
      return value unless reference.relative?

      URI.join(base_url.to_s, value).to_s
    rescue URI::InvalidURIError
      value
    end

    def http_uri(value)
      uri = URI.parse(value.to_s)
      return unless uri.is_a?(URI::HTTP) && uri.host.present? && %w[http https].include?(uri.scheme)

      uri
    rescue URI::InvalidURIError
      nil
    end
  end
end
