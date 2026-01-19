module DocumentArchive
  module Api
    class DocumentsController < BaseController
      def index
        limit = (params[:limit] || 20).to_i
        offset = (params[:offset] || 0).to_i

        documents = Document.includes(:articles)
                            .order(created_at: :desc)
                            .limit(limit)
                            .offset(offset)

        render json: {
          total: Document.count,
          documents: documents.map { |document| serialize_document(document) }
        }
      end

      def show
        document = Document.includes(:articles).find(params[:id])
        render json: {
          id: document.id,
          name: document.name,
          createdAt: document.created_at.iso8601,
          articles: document.articles.map { |article| serialize_article(article) }
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Document not found" }, status: :not_found
      end

      private

      def serialize_document(document)
        {
          id: document.id,
          name: document.name,
          articleCount: document.articles.count,
          createdAt: document.created_at.iso8601
        }
      end

      def serialize_article(article)
        {
          id: article.id,
          title: article.title,
          documentId: article.document_id,
          summary: article.summary,
          categories: article.categories || [],
          keywords: article.keywords || [],
          pageStart: article.page_start,
          pageEnd: article.page_end
        }
      end
    end
  end
end
