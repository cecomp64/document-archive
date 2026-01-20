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
          results: results.map { |embedding| serialize_embedding_result(embedding) }
        }
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def search_keywords
        query = params[:query]
        limit = (params[:limit] || 10).to_i
        offset = (params[:offset] || 0).to_i

        if query.blank?
          render json: { error: "Query parameter is required" }, status: :bad_request
          return
        end

        search_terms = query.downcase.split(/\s+/)

        # Search for articles where any keyword matches any search term
        articles = Article.includes(:document)
                          .where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(keywords) AS kw WHERE LOWER(kw) LIKE ANY(ARRAY[:patterns]))",
                                 patterns: search_terms.map { |t| "%#{t}%" })
                          .order(created_at: :desc)

        total = articles.count
        results = articles.limit(limit).offset(offset)

        render json: {
          total: total,
          results: results.map { |article| serialize_article(article) }
        }
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def search_categories
        query = params[:query]
        limit = (params[:limit] || 10).to_i
        offset = (params[:offset] || 0).to_i

        if query.blank?
          render json: { error: "Query parameter is required" }, status: :bad_request
          return
        end

        search_terms = query.downcase.split(/\s+/)

        # Search for articles where any category matches any search term
        articles = Article.includes(:document)
                          .where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(categories) AS cat WHERE LOWER(cat) LIKE ANY(ARRAY[:patterns]))",
                                 patterns: search_terms.map { |t| "%#{t}%" })
                          .order(created_at: :desc)

        total = articles.count
        results = articles.limit(limit).offset(offset)

        render json: {
          total: total,
          results: results.map { |article| serialize_article(article) }
        }
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def search_summary
        query = params[:query]
        limit = (params[:limit] || 10).to_i
        offset = (params[:offset] || 0).to_i

        if query.blank?
          render json: { error: "Query parameter is required" }, status: :bad_request
          return
        end

        search_terms = query.downcase.split(/\s+/)

        # Search for articles where summary contains any search term
        articles = Article.includes(:document)
                          .where("LOWER(summary) LIKE ANY(ARRAY[:patterns])",
                                 patterns: search_terms.map { |t| "%#{t}%" })
                          .order(created_at: :desc)

        total = articles.count
        results = articles.limit(limit).offset(offset)

        render json: {
          total: total,
          results: results.map { |article| serialize_article(article) }
        }
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      private

      def serialize_embedding_result(embedding)
        article = embedding.article
        document = article.document
        {
          id: article.id,
          title: article.title,
          documentId: article.document_id,
          documentName: document&.name,
          summary: article.summary,
          categories: article.categories || [],
          keywords: article.keywords || [],
          pageStart: article.page_start,
          pageEnd: article.page_end,
          similarity: 1 - embedding.neighbor_distance,
          pdfUrl: document&.pdf_url,
          txtUrl: document&.txt_url,
          markdownUrl: document&.markdown_url
        }
      end

      def serialize_article(article)
        document = article.document
        {
          id: article.id,
          title: article.title,
          documentId: article.document_id,
          documentName: document&.name,
          summary: article.summary,
          categories: article.categories || [],
          keywords: article.keywords || [],
          pageStart: article.page_start,
          pageEnd: article.page_end,
          pdfUrl: document&.pdf_url,
          txtUrl: document&.txt_url,
          markdownUrl: document&.markdown_url
        }
      end
    end
  end
end
