# frozen_string_literal: true

require "digest"
require "feedjira"

module Feeds
  class Importer
    Result = Data.define(:feed, :imported_entries, :not_modified) do
      def not_modified?
        not_modified
      end
    end

    def initialize(feed, fetcher: nil, clock: -> { Time.current })
      @feed = feed
      @fetcher = fetcher || Fetcher.new(feed)
      @clock = clock
    end

    def call
      @feed.update!(status: :refreshing, fetch_error: nil)
      fetched = @fetcher.call
      fetched.not_modified? ? finish_not_modified(fetched) : import(fetched)
    rescue StandardError => error
      mark_error(error)
      raise
    end

    private

    def finish_not_modified(fetched)
      @feed.update!(
        status: :ready,
        fetch_error: nil,
        etag: fetched.etag,
        last_modified: fetched.last_modified,
        last_fetched_at: @clock.call
      )

      Result.new(feed: @feed, imported_entries: 0, not_modified: true)
    end

    def import(fetched)
      parsed_feed = Feedjira.parse(fetched.body)
      imported_entries = 0

      Feed.transaction do
        assign_feed_metadata(parsed_feed, fetched)

        parsed_feed.entries.each do |parsed_entry|
          import_entry(parsed_entry)
          imported_entries += 1
        end

        @feed.status = :ready
        @feed.fetch_error = nil
        @feed.last_fetched_at = @clock.call
        @feed.save!
      end

      Result.new(feed: @feed, imported_entries: imported_entries, not_modified: false)
    end

    def assign_feed_metadata(parsed_feed, fetched)
      @feed.assign_attributes(
        title: normalize(parsed_feed.title) || @feed.title.presence || "Untitled feed",
        site_url: normalize(parsed_feed.url),
        description: normalize(parsed_feed.description),
        etag: fetched.etag,
        last_modified: fetched.last_modified
      )
    end

    def import_entry(parsed_entry)
      attributes = entry_attributes(parsed_entry)
      external_id = external_id_for(parsed_entry, attributes)
      entry = @feed.entries.find_or_initialize_by(external_id: external_id)
      entry.assign_attributes(attributes)
      entry.save! if entry.new_record? || entry.changed?
      entry
    end

    def entry_attributes(parsed_entry)
      {
        title: normalize(parsed_entry.title) || "Untitled entry",
        url: normalize(parsed_entry.url),
        author: normalize(parsed_entry.author),
        summary: normalize(parsed_entry.summary),
        content: normalize(parsed_entry.content),
        published_at: parsed_entry.published
      }
    end

    def external_id_for(parsed_entry, attributes)
      candidate = normalize(parsed_entry.entry_id) || attributes[:url]
      return bounded_identifier(candidate) if candidate

      fingerprint = [
        attributes[:title],
        attributes[:author],
        attributes[:summary],
        attributes[:content],
        attributes[:published_at]&.iso8601
      ].join("\u001F")
      Digest::SHA256.hexdigest(fingerprint)
    end

    def bounded_identifier(identifier)
      return identifier if identifier.bytesize <= 255

      Digest::SHA256.hexdigest(identifier)
    end

    def normalize(value)
      return if value.nil?

      value.to_s
        .encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "�")
        .scrub
        .strip
        .presence
    end

    def mark_error(error)
      return unless @feed.persisted?

      message = normalize(error.message) || error.class.name
      @feed.update_columns(
        status: Feed.statuses.fetch(:error),
        fetch_error: message.truncate(2_000),
        updated_at: @clock.call
      )
    rescue ActiveRecord::ActiveRecordError
      nil
    end
  end
end
