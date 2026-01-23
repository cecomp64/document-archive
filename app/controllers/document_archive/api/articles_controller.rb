module DocumentArchive
  module Api
    class ArticlesController < BaseController
      def index
        limit = (params[:limit] || 20).to_i
        offset = (params[:offset] || 0).to_i
        start_year = params[:start_year].presence&.to_i
        end_year = params[:end_year].presence&.to_i
        category = params[:category].presence
        keyword = params[:keyword].presence

        articles = Article.joins(:document).includes(:document)

        # Apply year filtering on the document's publication_date
        if start_year.present?
          articles = articles.where("EXTRACT(YEAR FROM document_archive_documents.publication_date) >= ?", start_year)
        end
        if end_year.present?
          articles = articles.where("EXTRACT(YEAR FROM document_archive_documents.publication_date) <= ?", end_year)
        end

        # Apply category filter (exact match)
        if category.present?
          articles = articles.where("categories @> ?", [category].to_json)
        end

        # Apply keyword filter (exact match)
        if keyword.present?
          articles = articles.where("keywords @> ?", [keyword].to_json)
        end

        total = articles.count

        # Sort by document's publication_date (nulls last), then by created_at
        articles = articles.order(Arel.sql("document_archive_documents.publication_date DESC NULLS LAST, document_archive_articles.created_at DESC"))
                           .limit(limit)
                           .offset(offset)

        render json: {
          total: total,
          articles: articles.map { |article| serialize_article(article) }
        }
      end

      private

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
