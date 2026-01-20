module DocumentArchive
  class StaticPagesController < ApplicationController
    def index
    end

    def articles
    end

    def documents
    end

    def document_show
      @document_id = params[:id]
    end

    def document_markdown
      @document_id = params[:id]
    end
  end
end
