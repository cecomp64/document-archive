module DocumentArchive
  module Api
    class SearchController < BaseController
      def search_text
        query = params[:query]
        limit = (params[:limit] || 10).to_i

        if query.blank?
          render json: { error: "Query parameter is required" }, status: :bad_request
          return
        end

        embedding_service = GeminiEmbeddingService.new
        query_embedding = embedding_service.embed(query)

        results = Embedding.nearest_neighbors(:vector, query_embedding, distance: "cosine")
                           .limit(limit)
                           .includes(article: :document)

        render json: {
          results: results.map { |embedding| serialize_result(embedding) }
        }
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      private

      def serialize_result(embedding)
        article = embedding.article
        {
          id: article.id,
          title: article.title,
          documentId: article.document_id,
          summary: article.summary,
          categories: article.categories || [],
          keywords: article.keywords || [],
          pageStart: article.page_start,
          pageEnd: article.page_end,
          similarity: 1 - embedding.neighbor_distance
        }
      end
    end
  end
end
