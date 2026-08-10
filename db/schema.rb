# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_09_124500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "entries", force: :cascade do |t|
    t.string "author"
    t.text "content"
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.bigint "feed_id", null: false
    t.datetime "published_at"
    t.text "summary"
    t.string "title", default: "Untitled entry", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["feed_id", "external_id"], name: "index_entries_on_feed_id_and_external_id", unique: true
    t.index ["feed_id", "published_at"], name: "index_entries_on_feed_id_and_published_at"
    t.index ["feed_id"], name: "index_entries_on_feed_id"
  end

  create_table "entry_reads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entry_id", null: false
    t.datetime "read_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["entry_id"], name: "index_entry_reads_on_entry_id"
    t.index ["user_id", "entry_id"], name: "index_entry_reads_on_user_id_and_entry_id", unique: true
    t.index ["user_id"], name: "index_entry_reads_on_user_id"
  end

  create_table "feeds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "etag"
    t.text "fetch_error"
    t.datetime "last_fetched_at"
    t.string "last_modified"
    t.string "site_url"
    t.boolean "starter", default: false, null: false
    t.string "status", default: "pending", null: false
    t.string "title", default: "Untitled feed", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["url"], name: "index_feeds_on_url", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "feed_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["feed_id"], name: "index_subscriptions_on_feed_id"
    t.index ["user_id", "feed_id"], name: "index_subscriptions_on_user_id_and_feed_id", unique: true
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "entries", "feeds"
  add_foreign_key "entry_reads", "entries"
  add_foreign_key "entry_reads", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "subscriptions", "feeds"
  add_foreign_key "subscriptions", "users"
end
