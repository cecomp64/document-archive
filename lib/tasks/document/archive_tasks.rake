namespace :document_archive do
  desc "Export documents, articles, and embeddings to JSON with URLs for remote import"
  task :export, [:output_dir, :chunk_size] => :environment do |_t, args|
    output_dir = args[:output_dir] || "export"
    chunk_size = (args[:chunk_size] || 10).to_i

    FileUtils.mkdir_p(output_dir)

    exporter = DocumentArchive::ChunkedExporter.new(output_dir, chunk_size)
    stats = exporter.export

    puts "\nExport complete to #{output_dir}/"
    puts "  Documents:   #{stats[:documents]} (#{stats[:chunks]} chunks)"
    puts "  Articles:    #{stats[:articles]}"
    puts "  Embeddings:  #{stats[:embeddings]}"
    puts "\nImport with:"
    puts "  for f in #{output_dir}/chunk_*.json; do"
    puts "    curl -X POST https://your-app/document_archive/api/import \\"
    puts "      -H 'Authorization: Bearer $TOKEN' \\"
    puts "      -H 'Content-Type: application/json' -d @$f"
    puts "  done"
  end

  desc "Upload chunked export files to a remote API endpoint"
  task :upload_chunks, [:directory, :api_url, :token] => :environment do |_t, args|
    directory = args[:directory]
    api_url = args[:api_url]
    token = args[:token] || ENV["IMPORT_API_TOKEN"]

    if directory.blank? || api_url.blank?
      puts "Usage: rake document_archive:upload_chunks[export,https://your-app.com/document_archive/api/import,your-token]"
      puts "  Token can also be set via IMPORT_API_TOKEN environment variable"
      exit 1
    end

    if token.blank?
      puts "Error: Token is required (pass as 3rd argument or set IMPORT_API_TOKEN env var)"
      exit 1
    end

    unless Dir.exist?(directory)
      puts "Error: Directory '#{directory}' does not exist"
      exit 1
    end

    chunks = Dir.glob(File.join(directory, "chunk_*.json")).sort
    if chunks.empty?
      puts "No chunk files found in #{directory}"
      exit 1
    end

    puts "Found #{chunks.size} chunks to upload to #{api_url}"
    puts ""

    uri = URI.parse(api_url)
    successful = 0
    failed = 0

    chunks.each_with_index do |chunk_file, index|
      print "Uploading #{File.basename(chunk_file)} (#{index + 1}/#{chunks.size})... "

      begin
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = 30
        http.read_timeout = 120

        request = Net::HTTP::Post.new(uri.path)
        request["Authorization"] = "Bearer #{token}"
        request["Content-Type"] = "application/json"
        request.body = File.read(chunk_file)

        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          result = JSON.parse(response.body)
          stats = result["imported"]
          puts "OK (#{stats['documents']} docs, #{stats['articles']} articles, #{stats['embeddings']} embeddings)"
          successful += 1
        else
          puts "FAILED (#{response.code}: #{response.body.truncate(100)})"
          failed += 1
        end
      rescue StandardError => e
        puts "ERROR (#{e.message})"
        failed += 1
      end
    end

    puts ""
    puts "Upload complete: #{successful} successful, #{failed} failed"
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

  class ChunkedExporter
    def initialize(output_dir, chunk_size)
      @output_dir = output_dir
      @chunk_size = chunk_size
      @stats = { documents: 0, articles: 0, embeddings: 0, chunks: 0 }
    end

    def export
      documents = Document.includes(:articles, pdf_attachment: :blob, txt_attachment: :blob,
                                    markdown_attachment: :blob, json_attachment: :blob)

      documents.each_slice(@chunk_size).with_index do |doc_batch, index|
        chunk_data = export_chunk(doc_batch)
        filename = File.join(@output_dir, "chunk_#{index.to_s.rjust(3, '0')}.json")

        File.write(filename, JSON.generate(chunk_data))
        puts "  Written #{filename} (#{doc_batch.size} documents)"

        @stats[:chunks] += 1
      end

      @stats
    end

    private

    def export_chunk(documents)
      doc_ids = documents.map(&:id)
      articles = Article.where(document_id: doc_ids).includes(:embedding)

      {
        documents: documents.map { |doc| serialize_document(doc) },
        articles: articles.map { |article| serialize_article(article) },
        embeddings: articles.filter_map { |article| serialize_embedding(article.embedding) }
      }
    end

    def serialize_document(doc)
      @stats[:documents] += 1
      {
        id: doc.id,
        name: doc.name,
        pdf_url: attachment_url(doc.pdf),
        txt_url: attachment_url(doc.txt),
        markdown_url: attachment_url(doc.markdown),
        json_url: attachment_url(doc.json)
      }
    end

    def serialize_article(article)
      @stats[:articles] += 1
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

    def serialize_embedding(embedding)
      return nil unless embedding

      @stats[:embeddings] += 1
      {
        articleId: embedding.article_id,
        vector: embedding.vector
      }
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
