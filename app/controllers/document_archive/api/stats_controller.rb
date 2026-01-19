module DocumentArchive
  module Api
    class StatsController < BaseController
      def show
        render json: {
          articles: Article.count,
          documents: Document.count,
          embeddings: Embedding.count
        }
      end
    end
  end
end
