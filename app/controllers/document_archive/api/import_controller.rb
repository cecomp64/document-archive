module DocumentArchive
  module Api
    class ImportController < BaseController
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

        uri = URI.parse(url)
        filename = File.basename(uri.path)

        response = Net::HTTP.get_response(uri)
        raise "Failed to fetch #{url}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        document.public_send(attachment_name).attach(
          io: StringIO.new(response.body),
          filename: filename,
          content_type: content_type
        )
        @stats[:attachments] += 1
      rescue StandardError => e
        Rails.logger.warn("Failed to attach #{attachment_name} from #{url}: #{e.message}")
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
