# frozen_string_literal: true

class ReaderController < InertiaController
  def index
    render_reader
  end

  def mark_all_read
    mark_entries_read(accessible_entries)
    redirect_to dashboard_path, notice: "Everything is caught up"
  end

  protected

  def render_reader(selected_feed: nil, selected_entry: nil)
    render inertia: "reader/index", props: Reader::PagePayload.new(
      user: Current.user,
      selected_feed: selected_feed,
      selected_entry: selected_entry,
      page: reader_page
    ).as_json
  end

  def reader_page
    value = params[:page]
    page = if value.is_a?(Integer)
      value
    elsif value.is_a?(String)
      Integer(value, 10, exception: false)
    end

    return 1 unless page&.positive?

    [ page, Reader::PagePayload::MAX_PAGE ].min
  end

  def accessible_entries
    Entry.where(feed_id: Current.user.feed_ids)
  end

  def mark_entries_read(entries)
    unread_ids = entries.where.not(id: Current.user.entry_reads.select(:entry_id)).pluck(:id)
    now = Time.current
    rows = unread_ids.map { |entry_id| { user_id: Current.user.id, entry_id: entry_id, read_at: now, created_at: now, updated_at: now } }
    EntryRead.insert_all(rows, unique_by: :index_entry_reads_on_user_id_and_entry_id) if rows.any?
  end
end
