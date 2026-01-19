module DocumentArchive
  module Api
    class ArticlesController < BaseController
      def index
        limit = (params[:limit] || 20).to_i
        offset = (params[:offset] || 0).to_i

        articles = Article.includes(:document)
                          .order(created_at: :desc)
                          .limit(limit)
                          .offset(offset)

        render json: {
          total: Article.count,
          articles: articles.map { |article| serialize_article(article) }
        }
      end

      private

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
