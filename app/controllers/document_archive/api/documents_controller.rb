module DocumentArchive
  module Api
    class DocumentsController < BaseController
      def index
        limit = (params[:limit] || 20).to_i
        offset = (params[:offset] || 0).to_i
        start_year = params[:start_year].presence&.to_i
        end_year = params[:end_year].presence&.to_i
        group_by_year = params[:group_by_year] == "true"

        documents = Document.includes(:articles)

        # Apply year filtering
        if start_year.present?
          documents = documents.where("EXTRACT(YEAR FROM publication_date) >= ?", start_year)
        end
        if end_year.present?
          documents = documents.where("EXTRACT(YEAR FROM publication_date) <= ?", end_year)
        end

        total = documents.count

        # Sort by publication_date (nulls last), then by created_at
        documents = documents.order(Arel.sql("publication_date DESC NULLS LAST, created_at DESC"))
                             .limit(limit)
                             .offset(offset)

        if group_by_year
          # Group documents by year
          grouped = documents.group_by { |doc| doc.publication_date&.year }
          years_data = grouped.map do |year, docs|
            {
              year: year,
              documents: docs.map { |document| serialize_document(document) }
            }
          end.sort_by { |g| g[:year] || 0 }.reverse

          render json: {
            total: total,
            grouped: true,
            years: years_data
          }
        else
          render json: {
            total: total,
            documents: documents.map { |document| serialize_document(document) }
          }
        end
      end

      def show
        document = Document.includes(:articles).find(params[:id])
        render json: {
          id: document.id,
          name: document.name,
          createdAt: document.created_at.iso8601,
          pdfUrl: document.pdf_url,
          txtUrl: document.txt_url,
          markdownUrl: document.markdown_url,
          jsonUrl: document.json_url,
          articles: document.articles.map { |article| serialize_article(article, document) }
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Document not found" }, status: :not_found
      end

      def markdown
        document = Document.find(params[:id])

        markdown_content = nil
        html_content = nil
        if document.markdown.present?
          markdown_content = fetch_markdown_content(document)
          html_content = render_markdown_to_html(markdown_content) if markdown_content
        end

        render json: {
          id: document.id,
          name: document.name,
          markdownContent: markdown_content,
          htmlContent: html_content
        }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Document not found" }, status: :not_found
      end

      private

      def fetch_markdown_content(document)
        # If using S3 storage, fetch from S3 URL
        if document.markdown_url.present?
          require "net/http"
          uri = URI.parse(document.markdown_url)
          response = Net::HTTP.get_response(uri)
          return response.body if response.is_a?(Net::HTTPSuccess)
        end
        nil
      rescue StandardError => e
        Rails.logger.error "Failed to fetch markdown for document #{document.id}: #{e.message}"
        nil
      end

      def render_markdown_to_html(markdown)
        renderer = Redcarpet::Render::HTML.new(
          hard_wrap: true,
          link_attributes: { target: "_blank", rel: "noopener" }
        )
        markdown_parser = Redcarpet::Markdown.new(
          renderer,
          autolink: true,
          tables: true,
          fenced_code_blocks: true,
          strikethrough: true,
          highlight: true,
          superscript: true
        )
        markdown_parser.render(markdown)
      end

      def serialize_document(document)
        {
          id: document.id,
          name: document.name,
          articleCount: document.articles.count,
          createdAt: document.created_at.iso8601,
          publicationDate: document.publication_date&.iso8601,
          pdfUrl: document.pdf_url,
          txtUrl: document.txt_url,
          markdownUrl: document.markdown_url,
          jsonUrl: document.json_url
        }
      end

      def serialize_article(article, document = nil)
        document ||= article.document
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
