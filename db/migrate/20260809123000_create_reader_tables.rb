# frozen_string_literal: true

class CreateReaderTables < ActiveRecord::Migration[8.1]
  def change
    create_table :feeds do |t|
      t.string :url, null: false
      t.string :title, null: false, default: "Untitled feed"
      t.string :site_url
      t.text :description
      t.string :etag
      t.string :last_modified
      t.string :status, null: false, default: "pending"
      t.datetime :last_fetched_at
      t.text :fetch_error
      t.boolean :starter, null: false, default: false

      t.timestamps
    end
    add_index :feeds, :url, unique: true

    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :feed, null: false, foreign_key: true

      t.timestamps
    end
    add_index :subscriptions, [ :user_id, :feed_id ], unique: true

    create_table :entries do |t|
      t.references :feed, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :title, null: false, default: "Untitled entry"
      t.string :url
      t.string :author
      t.text :summary
      t.text :content
      t.datetime :published_at

      t.timestamps
    end
    add_index :entries, [ :feed_id, :external_id ], unique: true
    add_index :entries, [ :feed_id, :published_at ]

    create_table :entry_reads do |t|
      t.references :user, null: false, foreign_key: true
      t.references :entry, null: false, foreign_key: true
      t.datetime :read_at, null: false

      t.timestamps
    end
    add_index :entry_reads, [ :user_id, :entry_id ], unique: true
  end
end
