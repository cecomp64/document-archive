module DocumentArchive
  module Api
    class SearchController < BaseController
      def search_text
        query = params[:query]
        limit = (params[:limit] || 10).to_i
        offset = (params[:offset] || 0).to_i
        start_year = params[:start_year].presence&.to_i
        end_year = params[:end_year].presence&.to_i

        if query.blank? && params[:embedding].blank?
          render json: { error: "Query or embedding parameter is required" }, status: :bad_request
          return
        end

        # Use provided embedding if available, otherwise generate from query
        if params[:embedding].present?
          query_embedding = params[:embedding]
          embedding_model = nil
        else
          embedding_service = GeminiEmbeddingService.new
          query_embedding = embedding_service.embed(query)
          embedding_model = embedding_service.model_name
        end

        # Build the base scope with year filtering first
        base_scope = Embedding.joins(article: :document)

        if start_year.present?
          base_scope = base_scope.where("EXTRACT(YEAR FROM document_archive_documents.publication_date) >= ?", start_year)
        end
        if end_year.present?
          base_scope = base_scope.where("EXTRACT(YEAR FROM document_archive_documents.publication_date) <= ?", end_year)
        end

        total = base_scope.count

        # Apply nearest neighbors search on the filtered scope
        results = base_scope.nearest_neighbors(:vector, query_embedding, distance: "cosine")
                            .includes(article: :document)
                            .limit(limit)
                            .offset(offset)

        render json: {
          total: total,
          embedding_model: embedding_model,
          embedding: query_embedding,
          results: results.map { |embedding| serialize_embedding_result(embedding) }
        }
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def search_keywords
        query = params[:query]
        limit = (params[:limit] || 10).to_i
        offset = (params[:offset] || 0).to_i
        start_year = params[:start_year].presence&.to_i
        end_year = params[:end_year].presence&.to_i

        if query.blank?
          render json: { error: "Query parameter is required" }, status: :bad_request
          return
        end

        search_terms = query.downcase.split(/\s+/)

        # Search for articles where any keyword matches any search term
        articles = Article.joins(:document)
                          .includes(:document)
                          .where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(keywords) AS kw WHERE LOWER(kw) LIKE ANY(ARRAY[:patterns]))",
                                 patterns: search_terms.map { |t| "%#{t}%" })

        # Apply year filtering on the document's publication_date
        if start_year.present?
          articles = articles.where("EXTRACT(YEAR FROM document_archive_documents.publication_date) >= ?", start_year)
        end
        if end_year.present?
          articles = articles.where("EXTRACT(YEAR FROM document_archive_documents.publication_date) <= ?", end_year)
        end

        articles = articles.order(created_at: :desc)

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
        start_year = params[:start_year].presence&.to_i
        end_year = params[:end_year].presence&.to_i

        if query.blank?
          render json: { error: "Query parameter is required" }, status: :bad_request
          return
        end

        search_terms = query.downcase.split(/\s+/)

        # Search for articles where any category matches any search term
        articles = Article.joins(:document)
                          .includes(:document)
                          .where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(categories) AS cat WHERE LOWER(cat) LIKE ANY(ARRAY[:patterns]))",
                                 patterns: search_terms.map { |t| "%#{t}%" })

        # Apply year filtering on the document's publication_date
        if start_year.present?
          articles = articles.where("EXTRACT(YEAR FROM document_archive_documents.publication_date) >= ?", start_year)
        end
        if end_year.present?
          articles = articles.where("EXTRACT(YEAR FROM document_archive_documents.publication_date) <= ?", end_year)
        end

        articles = articles.order(created_at: :desc)

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
        start_year = params[:start_year].presence&.to_i
        end_year = params[:end_year].presence&.to_i

        if query.blank?
          render json: { error: "Query parameter is required" }, status: :bad_request
          return
        end

        search_terms = query.downcase.split(/\s+/)

        # Search for articles where summary contains any search term
        articles = Article.joins(:document)
                          .includes(:document)
                          .where("LOWER(summary) LIKE ANY(ARRAY[:patterns])",
                                 patterns: search_terms.map { |t| "%#{t}%" })

        # Apply year filtering on the document's publication_date
        if start_year.present?
          articles = articles.where("EXTRACT(YEAR FROM document_archive_documents.publication_date) >= ?", start_year)
        end
        if end_year.present?
          articles = articles.where("EXTRACT(YEAR FROM document_archive_documents.publication_date) <= ?", end_year)
        end

        articles = articles.order(created_at: :desc)

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
