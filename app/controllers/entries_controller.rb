# frozen_string_literal: true

class EntriesController < ReaderController
  before_action :set_entry

  def show
    render_reader(
      selected_feed: all_entries_scope? ? nil : @entry.feed,
      selected_entry: @entry
    )
  end

  def update
    Current.user.entry_reads.find_or_create_by!(entry: @entry) do |entry_read|
      entry_read.read_at = Time.current
    end
    redirect_to entry_path(@entry, **reader_location_params)
  end

  private

  def set_entry
    @entry = accessible_entries.includes(:feed).find(params[:id])
  end

  def all_entries_scope?
    params[:scope] == "all"
  end

  def reader_location_params
    {}.tap do |query|
      query[:scope] = "all" if all_entries_scope?
      query[:page] = reader_page if params.key?(:page)
    end
  end
end
