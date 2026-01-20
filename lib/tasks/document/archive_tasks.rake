namespace :document_archive do
  desc "Export documents, articles, and embeddings to JSON with URLs for remote import"
  task :export, [:output_file] => :environment do |_t, args|
    output_file = args[:output_file] || "export.json"

    exporter = DocumentArchive::JsonExporter.new
    data = exporter.export

    File.write(output_file, JSON.pretty_generate(data))
    puts "Exported to #{output_file}"
    puts "  Documents:   #{data[:documents].size}"
    puts "  Articles:    #{data[:articles].size}"
    puts "  Embeddings:  #{data[:embeddings].size}"
  end

  desc "Import documents, articles, and embeddings from JSON files"
  task :import, [:directory] => :environment do |_t, args|
    directory = args[:directory]

    if directory.blank?
      puts "Usage: rake document_archive:import[/path/to/json/files]"
      exit 1
    end

    unless Dir.exist?(directory)
      puts "Error: Directory '#{directory}' does not exist"
      exit 1
    end

    importer = DocumentArchive::JsonImporter.new(directory)
    importer.import
  end
end

module DocumentArchive
  class JsonImporter
    def initialize(directory)
      @directory = directory
      @document_id_map = {}
      @article_id_map = {}
      @stats = { documents: 0, articles: 0, embeddings: 0, attachments: 0 }
    end

    def import
      puts "Starting import from #{@directory}..."

      json_files = Dir.glob(File.join(@directory, "**", "*.json"))
                      .reject { |f| f.end_with?("-embeddings.json") }

      if json_files.empty?
        puts "No JSON files found in #{@directory}"
        return
      end

      ActiveRecord::Base.transaction do
        json_files.each { |file| import_file(file) }
      end

      print_summary
    end

    private

    def import_file(file)
      puts "Processing #{File.basename(file)}..."
      data = JSON.parse(File.read(file))

      document_name = File.basename(file, ".json")

      # Always create a document, even if JSON doesn't have explicit documents array
      if data["documents"].present?
        import_documents(data["documents"], document_name, file)
      else
        # Create a single document for this file
        document = Document.create!(name: document_name)
        # Use the document name as the ID for article lookups
        @document_id_map[document_name] = document.id
        @stats[:documents] += 1
        upload_attachments(document, document_name, file)
      end

      import_articles(data["articles"]) if data["articles"]

      embeddings_file = file.sub(".json", "-embeddings.json")
      import_embeddings(embeddings_file) if File.exist?(embeddings_file)
    end

    def import_documents(documents, document_name, json_file)
      documents.each do |doc_data|
        document = Document.create!(
          name: document_name
        )
        @document_id_map[doc_data["id"]] = document.id
        @stats[:documents] += 1

        # Upload attachments for this document
        upload_attachments(document, document_name, json_file)
      end
    end

    def upload_attachments(document, document_name, json_file)
      base_path = File.dirname(json_file)
      base_name = document_name

      # Upload JSON file
      if File.exist?(json_file)
        puts "  Uploading JSON: #{File.basename(json_file)}"
        document.json.attach(
          io: File.open(json_file),
          filename: File.basename(json_file),
          content_type: "application/json"
        )
        @stats[:attachments] += 1
      end

      # Upload PDF file
      pdf_file = find_attachment_file(base_path, base_name, %w[.pdf])
      if pdf_file
        puts "  Uploading PDF: #{File.basename(pdf_file)}"
        document.pdf.attach(
          io: File.open(pdf_file),
          filename: File.basename(pdf_file),
          content_type: "application/pdf"
        )
        @stats[:attachments] += 1
      end

      # Upload text file
      txt_file = find_attachment_file(base_path, base_name, %w[.txt])
      if txt_file
        puts "  Uploading TXT: #{File.basename(txt_file)}"
        document.txt.attach(
          io: File.open(txt_file),
          filename: File.basename(txt_file),
          content_type: "text/plain"
        )
        @stats[:attachments] += 1
      end

      # Upload markdown file
      md_file = find_attachment_file(base_path, base_name, %w[.md .markdown])
      if md_file
        puts "  Uploading Markdown: #{File.basename(md_file)}"
        document.markdown.attach(
          io: File.open(md_file),
          filename: File.basename(md_file),
          content_type: "text/markdown"
        )
        @stats[:attachments] += 1
      end
    end

    def find_attachment_file(base_path, base_name, extensions)
      extensions.each do |ext|
        # Try exact match with base name
        file_path = File.join(base_path, "#{base_name}#{ext}")
        return file_path if File.exist?(file_path)

        # Try case-insensitive search
        Dir.glob(File.join(base_path, "*#{ext}"), File::FNM_CASEFOLD).each do |found|
          found_base = File.basename(found, ext)
          if found_base.downcase == base_name.downcase
            return found
          end
        end
      end
      nil
    end

    def import_articles(articles)
      articles.each do |article_data|
        document_id = @document_id_map[article_data["documentId"]]

        unless document_id
          puts "  Warning: Document '#{article_data["documentId"]}' not found for article '#{article_data["id"]}'"
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

    def import_embeddings(embeddings_file)
      puts "  Processing embeddings from #{File.basename(embeddings_file)}..."
      data = JSON.parse(File.read(embeddings_file))

      data["embeddings"]&.each do |embedding_data|
        article_id = @article_id_map[embedding_data["articleId"]]

        unless article_id
          puts "    Warning: Article '#{embedding_data["articleId"]}' not found for embedding"
          next
        end

        Embedding.create!(
          article_id: article_id,
          vector: embedding_data["vector"]
        )
        @stats[:embeddings] += 1
      end
    end

    def print_summary
      puts "\nImport complete!"
      puts "  Documents:   #{@stats[:documents]}"
      puts "  Articles:    #{@stats[:articles]}"
      puts "  Embeddings:  #{@stats[:embeddings]}"
      puts "  Attachments: #{@stats[:attachments]}"
    end
  end

  class JsonExporter
    def export
      {
        documents: export_documents,
        articles: export_articles,
        embeddings: export_embeddings
      }
    end

    private

    def export_documents
      Document.includes(pdf_attachment: :blob, txt_attachment: :blob,
                        markdown_attachment: :blob, json_attachment: :blob).map do |doc|
        {
          id: doc.id,
          name: doc.name,
          pdf_url: attachment_url(doc.pdf),
          txt_url: attachment_url(doc.txt),
          markdown_url: attachment_url(doc.markdown),
          json_url: attachment_url(doc.json)
        }
      end
    end

    def export_articles
      Article.all.map do |article|
        {
          id: article.id,
          documentId: article.document_id,
          title: article.title,
          summary: article.summary,
          categories: article.categories,
          keywords: article.keywords,
          pageStart: article.page_start,
          pageEnd: article.page_end
        }
      end
    end

    def export_embeddings
      Embedding.all.map do |embedding|
        {
          articleId: embedding.article_id,
          vector: embedding.vector
        }
      end
    end

    def attachment_url(attachment)
      return nil unless attachment.attached?

      if Rails.application.config.active_storage.service == :amazon
        attachment.url(expires_in: 7.days)
      else
        Rails.application.routes.url_helpers.rails_blob_url(
          attachment,
          host: ENV.fetch("APP_HOST", "http://localhost:3000")
        )
      end
    end
  end
end
