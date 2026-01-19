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

ActiveRecord::Schema[8.1].define(version: 2026_01_18_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "document_archive_articles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "categories", default: []
    t.datetime "created_at", null: false
    t.uuid "document_id", null: false
    t.jsonb "keywords", default: []
    t.integer "page_end"
    t.integer "page_start"
    t.text "summary"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["categories"], name: "index_document_archive_articles_on_categories", using: :gin
    t.index ["document_id"], name: "index_document_archive_articles_on_document_id"
    t.index ["keywords"], name: "index_document_archive_articles_on_keywords", using: :gin
  end

  create_table "document_archive_documents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "document_archive_embeddings", force: :cascade do |t|
    t.uuid "article_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.vector "vector", limit: 1536
    t.index ["article_id"], name: "index_document_archive_embeddings_on_article_id"
    t.index ["vector"], name: "index_document_archive_embeddings_on_vector", opclass: :vector_cosine_ops, using: :hnsw
  end

  add_foreign_key "document_archive_articles", "document_archive_documents", column: "document_id"
  add_foreign_key "document_archive_embeddings", "document_archive_articles", column: "article_id"
end
