require "net/http"
require 'open-uri'

module DocumentArchive
  module Api
    class ImportController < ActionController::API
      # Skip all inherited auth - this controller handles its own authentication
      # via IMPORT_API_TOKEN environment variable
      before_action :authenticate_import_token

      def create
        data = JSON.parse(request.body.read)
        importer = UrlImporter.new(data)
        result = importer.import

        render json: {
          success: true,
          imported: result
        }
      rescue JSON::ParserError => e
        render json: { error: "Invalid JSON: #{e.message}" }, status: :bad_request
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def reimport_embeddings
        data = JSON.parse(request.body.read)
        embeddings = data["embeddings"]
        document_name = data["document_name"]
        articles = data["articles"]

        if embeddings.blank?
          render json: { error: "No 'embeddings' key found in JSON" }, status: :bad_request
          return
        end

        # Build mapping from original article IDs to database UUIDs
        article_id_map = {}
        if document_name.present? && articles.present?
          document = Document.find_by(name: document_name)
          if document
            articles.each do |article_data|
              db_article = Article.find_by(
                document_id: document.id,
                title: article_data["title"]
              )
              article_id_map[article_data["id"]] = db_article.id if db_article
            end
          end
        end

        updated = 0
        created = 0
        skipped = 0
        errored = 0

        embeddings.each do |embedding_data|
          original_id = embedding_data["articleId"]
          vector = embedding_data["vector"]

          unless original_id && vector
            skipped += 1
            next
          end

          # Try mapped ID first, then fall back to direct UUID lookup
          db_article_id = article_id_map[original_id]
          db_article_id ||= original_id if Article.exists?(id: original_id)

          unless db_article_id
            skipped += 1
            next
          end

          begin
            existing = Embedding.find_by(article_id: db_article_id)
            if existing
              existing.update!(vector: vector)
              updated += 1
            else
              Embedding.create!(article_id: db_article_id, vector: vector)
              created += 1
            end
          rescue StandardError => e
            Rails.logger.warn("Embedding error for article '#{original_id}': #{e.message}")
            errored += 1
          end
        end

        render json: {
          success: true,
          reimported: { updated: updated, created: created, skipped: skipped, errored: errored }
        }
      rescue JSON::ParserError => e
        render json: { error: "Invalid JSON: #{e.message}" }, status: :bad_request
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def authenticate_import_token
        expected_token = ENV["IMPORT_API_TOKEN"]

        if expected_token.blank?
          render json: { error: "IMPORT_API_TOKEN not configured" }, status: :service_unavailable
          return
        end

        provided_token = request.headers["Authorization"]&.delete_prefix("Bearer ")

        unless ActiveSupport::SecurityUtils.secure_compare(provided_token.to_s, expected_token)
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end
    end

    class UrlImporter
      def initialize(data)
        @data = data
        @document_id_map = {}
        @article_id_map = {}
        @stats = { documents: 0, articles: 0, embeddings: 0, attachments: 0 }
      end

      def import
        ActiveRecord::Base.transaction do
          import_documents(@data["documents"]) if @data["documents"]
          import_articles(@data["articles"]) if @data["articles"]
          import_embeddings(@data["embeddings"]) if @data["embeddings"]
        end

        @stats
      end

      private

      def import_documents(documents)
        documents.each do |doc_data|
          document = Document.create!(name: doc_data["name"])
          @document_id_map[doc_data["id"]] = document.id
          @stats[:documents] += 1

          attach_from_url(document, :pdf, doc_data["pdf_url"], "application/pdf")
          attach_from_url(document, :txt, doc_data["txt_url"], "text/plain")
          attach_from_url(document, :markdown, doc_data["markdown_url"], "text/markdown")
          attach_from_url(document, :json, doc_data["json_url"], "application/json")
        end
      end

      def attach_from_url(document, attachment_name, url, content_type)
        return if url.blank?
        raise "Document is nil when attaching #{attachment_name}" if document.nil?
        raise "Document not persisted when attaching #{attachment_name}" unless document.persisted?

        # Reload the document to ensure we have fresh ActiveStorage associations
        document.reload

        # URI.open handles the full signed S3 URL correctly
        downloaded_file = URI.parse(url).open(open_timeout: 10, read_timeout: 60)

        # Use the original filename from the URL path
        filename = File.basename(URI.parse(url).path)

        #document.public_send(attachment_name).attach(
        blob = ActiveStorage::Blob.create_and_upload!(
          io: downloaded_file,
          filename: filename,
          content_type: content_type,
          identify: false
        )

        document.public_send(attachment_name).attach(blob)
        Rails.logger.info "New Key: #{blob.key}"
        Rails.logger.info "Exists in S3? #{blob.service.exist?(blob.key)}"
        @stats[:attachments] += 1
      rescue StandardError => e
        Rails.logger.error("Failed to attach #{attachment_name} for doc #{document&.id}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
        raise
      end

      def import_articles(articles)
        articles.each do |article_data|
          document_id = @document_id_map[article_data["documentId"]]

          unless document_id
            Rails.logger.warn("Document '#{article_data["documentId"]}' not found for article")
            next
          end

          article = Article.create!(
            document_id: document_id,
            title: article_data["title"],
            summary: article_data["summary"],
            categories: article_data["categories"] || [],
            keywords: article_data["keywords"] || [],
            page_start: article_data["pageStart"],
            page_end: article_data["pageEnd"]
          )
          @article_id_map[article_data["id"]] = article.id
          @stats[:articles] += 1
        end
      end

      def import_embeddings(embeddings)
        embeddings.each do |embedding_data|
          article_id = @article_id_map[embedding_data["articleId"]]

          unless article_id
            Rails.logger.warn("Article '#{embedding_data["articleId"]}' not found for embedding")
            next
          end

          Embedding.create!(
            article_id: article_id,
            vector: embedding_data["vector"]
          )
          @stats[:embeddings] += 1
        end
      end
    end
  end
end
