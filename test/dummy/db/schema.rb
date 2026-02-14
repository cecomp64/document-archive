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

ActiveRecord::Schema[7.1].define(version: 2026_02_13_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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
    t.string "json_content_type"
    t.string "json_file_name"
    t.bigint "json_file_size"
    t.datetime "json_updated_at"
    t.string "markdown_content_type"
    t.string "markdown_file_name"
    t.bigint "markdown_file_size"
    t.datetime "markdown_updated_at"
    t.string "name"
    t.string "pdf_content_type"
    t.string "pdf_file_name"
    t.bigint "pdf_file_size"
    t.datetime "pdf_updated_at"
    t.string "txt_content_type"
    t.string "txt_file_name"
    t.bigint "txt_file_size"
    t.datetime "txt_updated_at"
    t.datetime "updated_at", null: false
    t.date "publication_date"
    t.index ["publication_date"], name: "index_document_archive_documents_on_publication_date"
  end

  create_table "document_archive_embeddings", force: :cascade do |t|
    t.uuid "article_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.vector "vector", limit: 768
    t.index ["article_id"], name: "index_document_archive_embeddings_on_article_id"
    t.index ["vector"], name: "index_document_archive_embeddings_on_vector", opclass: :vector_cosine_ops, using: :hnsw
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "document_archive_articles", "document_archive_documents", column: "document_id"
  add_foreign_key "document_archive_embeddings", "document_archive_articles", column: "article_id"
end
