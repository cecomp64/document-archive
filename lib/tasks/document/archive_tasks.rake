namespace :document_archive do
  desc "Derive publication dates from document names and update documents"
  task derive_publication_dates: :environment do
    updated = 0
    skipped = 0
    failed = 0

    DocumentArchive::Document.find_each do |document|
      date = DocumentArchive::PublicationDateParser.parse(document.name)

      if date
        document.update!(publication_date: date)
        puts "  #{document.name} => #{date}"
        updated += 1
      else
        puts "  #{document.name} => (no date found)"
        skipped += 1
      end
    rescue StandardError => e
      puts "  #{document.name} => ERROR: #{e.message}"
      failed += 1
    end

    puts "\nComplete: #{updated} updated, #{skipped} skipped, #{failed} failed"
  end

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

  desc "Upload embedding files to a remote API endpoint to update existing embeddings"
  task :upload_embeddings, [:directory, :api_url, :token] => :environment do |_t, args|
    directory = args[:directory]
    api_url = args[:api_url]
    token = args[:token] || ENV["IMPORT_API_TOKEN"]

    if directory.blank? || api_url.blank?
      puts "Usage: rake document_archive:upload_embeddings[/path/to/embeddings,https://your-app.com/document_archive/api/import-embeddings,your-token]"
      puts "  Token can also be set via IMPORT_API_TOKEN environment variable"
      puts "  Finds all *-embeddings.json files recursively in the directory"
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

    files = Dir.glob(File.join(directory, "**", "*-embeddings.json")).sort
    if files.empty?
      puts "No *-embeddings.json files found in #{directory}"
      exit 1
    end

    puts "Found #{files.size} embedding files to upload to #{api_url}"
    puts ""

    uri = URI.parse(api_url)
    successful = 0
    failed = 0
    totals = { updated: 0, created: 0, skipped: 0 }

    files.each_with_index do |file, index|
      print "Uploading #{File.basename(file)} (#{index + 1}/#{files.size})... "

      begin
        # Merge companion data so the server can map original IDs to DB UUIDs
        embedding_data = JSON.parse(File.read(file))
        companion_file = file.sub("-embeddings.json", ".json")
        if File.exist?(companion_file)
          companion_data = JSON.parse(File.read(companion_file))
          embedding_data["document_name"] = File.basename(companion_file, ".json")
          embedding_data["articles"] = companion_data["articles"] if companion_data["articles"]
        end

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = 30
        http.read_timeout = 120

        request = Net::HTTP::Post.new(uri.path)
        request["Authorization"] = "Bearer #{token}"
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(embedding_data)

        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          result = JSON.parse(response.body)
          stats = result["reimported"]
          puts "OK (#{stats['updated']} updated, #{stats['created']} created, #{stats['skipped']} skipped)"
          totals[:updated] += stats["updated"]
          totals[:created] += stats["created"]
          totals[:skipped] += stats["skipped"]
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
    puts "  Updated:  #{totals[:updated]}"
    puts "  Created:  #{totals[:created]}"
    puts "  Skipped:  #{totals[:skipped]}"
  end

  desc "Upload local JSON files and attachments directly to a remote API via S3"
  task :upload_import, [:directory, :api_url, :token, :chunk_size] => :environment do |_t, args|
    directory = args[:directory]
    api_url = args[:api_url]
    token = args[:token] || ENV["IMPORT_API_TOKEN"]
    chunk_size = (args[:chunk_size] || 5).to_i

    if directory.blank? || api_url.blank?
      puts "Usage: rake document_archive:upload_import[/path/to/json/files,https://your-app.com/document_archive/api/import,your-token,5]"
      puts "  Token can also be set via IMPORT_API_TOKEN environment variable"
      puts "  chunk_size (optional, default 5) controls how many documents per API call"
      puts ""
      puts "Required env vars for S3: S3_ACCESS_KEY, S3_ACCESS_SECRET, S3_REGION, S3_BUCKET_NAME"
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

    %w[S3_ACCESS_KEY S3_ACCESS_SECRET S3_REGION S3_BUCKET_NAME].each do |var|
      if ENV[var].blank?
        puts "Error: #{var} environment variable is required"
        exit 1
      end
    end

    importer = DocumentArchive::FileToRemoteImporter.new(
      directory: directory,
      api_url: api_url,
      token: token,
      chunk_size: chunk_size
    )
    importer.run
  end

  desc "Re-import embeddings for existing articles from JSON files"
  task :reimport_embeddings, [:directory] => :environment do |_t, args|
    directory = args[:directory]

    if directory.blank?
      puts "Usage: rake document_archive:reimport_embeddings[/path/to/embeddings]"
      puts "  Expects *-embeddings.json files alongside their companion *.json data files"
      exit 1
    end

    unless Dir.exist?(directory)
      puts "Error: Directory '#{directory}' does not exist"
      exit 1
    end

    embedding_files = Dir.glob(File.join(directory, "**", "*-embeddings.json")).sort
    if embedding_files.empty?
      puts "No *-embeddings.json files found in #{directory}"
      exit 1
    end

    updated = 0
    created = 0
    skipped = 0
    errored = 0

    embedding_files.each do |embedding_file|
      puts "Processing #{File.basename(embedding_file)}..."

      # Find the companion data file to build article ID mapping
      companion_file = embedding_file.sub("-embeddings.json", ".json")
      unless File.exist?(companion_file)
        puts "  Warning: Companion file #{File.basename(companion_file)} not found, skipping"
        skipped += 1
        next
      end

      # Build mapping from original article IDs to database UUIDs
      companion_data = JSON.parse(File.read(companion_file))
      document_name = File.basename(companion_file, ".json")
      article_id_map = {}

      document = DocumentArchive::Document.find_by(name: document_name)
      unless document
        puts "  Warning: Document '#{document_name}' not found in database, skipping"
        skipped += 1
        next
      end

      (companion_data["articles"] || []).each do |article_data|
        db_article = DocumentArchive::Article.find_by(
          document_id: document.id,
          title: article_data["title"]
        )
        if db_article
          article_id_map[article_data["id"]] = db_article.id
        else
          puts "  Warning: Article '#{article_data["title"]}' not found in document '#{document_name}'"
        end
      end

      puts "  Matched #{article_id_map.size} articles"

      # Process embeddings
      embedding_data = JSON.parse(File.read(embedding_file))
      (embedding_data["embeddings"] || []).each do |entry|
        original_id = entry["articleId"]
        vector = entry["vector"]

        unless original_id && vector
          puts "  Skipping entry: missing articleId or vector"
          skipped += 1
          next
        end

        db_article_id = article_id_map[original_id]
        unless db_article_id
          puts "  Warning: No mapping for article '#{original_id}', skipping"
          skipped += 1
          next
        end

        begin
          existing = DocumentArchive::Embedding.find_by(article_id: db_article_id)
          if existing
            existing.update!(vector: vector)
            updated += 1
          else
            DocumentArchive::Embedding.create!(article_id: db_article_id, vector: vector)
            created += 1
          end
        rescue StandardError => e
          puts "  Error on article '#{original_id}': #{e.message}"
          errored += 1
        end
      end
    end

    puts "\nRe-import complete!"
    puts "  Updated:  #{updated}"
    puts "  Created:  #{created}"
    puts "  Skipped:  #{skipped}"
    puts "  Errored:  #{errored}" if errored > 0
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
        publication_date: doc.publication_date&.iso8601,
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

  class FileToRemoteImporter
    require "aws-sdk-s3"

    PRESIGNED_URL_EXPIRY = 7 * 24 * 60 * 60 # 7 days in seconds
    S3_KEY_PREFIX = "imports".freeze

    def initialize(directory:, api_url:, token:, chunk_size: 5)
      @directory = directory
      @api_url = api_url
      @token = token
      @chunk_size = chunk_size
      @stats = { documents: 0, articles: 0, embeddings: 0, attachments: 0, chunks_ok: 0, chunks_failed: 0 }
    end

    def run
      json_files = discover_json_files
      if json_files.empty?
        puts "No JSON files found in #{@directory}"
        return
      end

      total_chunks = (json_files.size.to_f / @chunk_size).ceil
      puts "Found #{json_files.size} document files in #{@directory}"
      puts "Will upload in #{total_chunks} chunks of #{@chunk_size} to #{@api_url}"
      puts ""

      json_files.each_slice(@chunk_size).with_index do |batch, index|
        process_chunk(batch, index, total_chunks)
      end

      print_summary
    end

    private

    def discover_json_files
      Dir.glob(File.join(@directory, "**", "*.json"))
         .reject { |f| f.end_with?("-embeddings.json") }
         .sort
    end

    def find_attachment_file(base_path, base_name, extensions)
      extensions.each do |ext|
        file_path = File.join(base_path, "#{base_name}#{ext}")
        return file_path if File.exist?(file_path)

        Dir.glob(File.join(base_path, "*#{ext}"), File::FNM_CASEFOLD).each do |found|
          found_base = File.basename(found, ext)
          return found if found_base.downcase == base_name.downcase
        end
      end
      nil
    end

    # --- S3 ---

    def s3_client
      @s3_client ||= Aws::S3::Client.new(
        access_key_id: ENV["S3_ACCESS_KEY"],
        secret_access_key: ENV["S3_ACCESS_SECRET"],
        region: ENV["S3_REGION"]
      )
    end

    def s3_bucket
      ENV["S3_BUCKET_NAME"]
    end

    def upload_to_s3(local_path, content_type)
      filename = File.basename(local_path)
      s3_key = "#{S3_KEY_PREFIX}/#{filename}"

      puts "    Uploading to S3: #{filename}"
      File.open(local_path, "rb") do |file|
        s3_client.put_object(
          bucket: s3_bucket,
          key: s3_key,
          body: file,
          content_type: content_type
        )
      end

      generate_presigned_url(s3_key)
    end

    def generate_presigned_url(s3_key)
      signer = Aws::S3::Presigner.new(client: s3_client)
      signer.presigned_url(
        :get_object,
        bucket: s3_bucket,
        key: s3_key,
        expires_in: PRESIGNED_URL_EXPIRY
      )
    end

    # --- Chunk processing ---

    def process_chunk(json_files, chunk_index, total_chunks)
      chunk_number = chunk_index + 1
      puts "Processing chunk #{chunk_number}/#{total_chunks} (#{json_files.size} documents)..."

      documents = []
      articles = []
      embeddings = []

      json_files.each do |json_file|
        doc_data = process_document_file(json_file)
        next unless doc_data

        documents.concat(doc_data[:documents])
        articles.concat(doc_data[:articles])
        embeddings.concat(doc_data[:embeddings])
      end

      payload = { documents: documents, articles: articles, embeddings: embeddings }
      post_chunk(payload, chunk_number, total_chunks)
    end

    def process_document_file(json_file)
      document_name = File.basename(json_file, ".json")
      base_path = File.dirname(json_file)
      puts "  Processing #{document_name}..."

      data = JSON.parse(File.read(json_file))

      # Generate a temporary UUID for cross-referencing within this chunk
      doc_id = SecureRandom.uuid

      # Upload attachments to S3 and get presigned URLs
      pdf_url = upload_attachment(base_path, document_name, %w[.pdf], "application/pdf")
      txt_url = upload_attachment(base_path, document_name, %w[.txt], "text/plain")
      markdown_url = upload_attachment(base_path, document_name, %w[.md .markdown], "text/markdown")
      json_url = upload_to_s3(json_file, "application/json")
      @stats[:attachments] += 1

      publication_date = PublicationDateParser.parse(document_name)

      document_entry = {
        id: doc_id,
        name: document_name,
        publication_date: publication_date&.iso8601,
        pdf_url: pdf_url,
        txt_url: txt_url,
        markdown_url: markdown_url,
        json_url: json_url
      }
      @stats[:documents] += 1

      # Build article entries, remapping documentId to our generated doc_id
      article_entries = (data["articles"] || []).map do |article_data|
        article_id = SecureRandom.uuid
        @stats[:articles] += 1

        {
          id: article_id,
          documentId: doc_id,
          title: article_data["title"],
          summary: article_data["summary"],
          categories: article_data["categories"] || [],
          keywords: article_data["keywords"] || [],
          pageStart: article_data["pageStart"],
          pageEnd: article_data["pageEnd"],
          _original_id: article_data["id"]
        }
      end

      # Build embedding entries from companion embeddings file
      embedding_entries = []
      embeddings_file = json_file.sub(".json", "-embeddings.json")
      if File.exist?(embeddings_file)
        embedding_data = JSON.parse(File.read(embeddings_file))

        # Map original article IDs to our generated UUIDs
        original_to_uuid = {}
        article_entries.each { |ae| original_to_uuid[ae[:_original_id]] = ae[:id] }

        (embedding_data["embeddings"] || []).each do |entry|
          mapped_article_id = original_to_uuid[entry["articleId"]]
          unless mapped_article_id
            puts "    Warning: No article match for embedding articleId '#{entry["articleId"]}'"
            next
          end

          embedding_entries << { articleId: mapped_article_id, vector: entry["vector"] }
          @stats[:embeddings] += 1
        end
      end

      # Strip internal _original_id before sending to API
      clean_articles = article_entries.map { |ae| ae.except(:_original_id) }

      { documents: [document_entry], articles: clean_articles, embeddings: embedding_entries }
    rescue JSON::ParserError => e
      puts "    Warning: Invalid JSON in #{json_file}: #{e.message}"
      nil
    rescue StandardError => e
      puts "    Error processing #{json_file}: #{e.message}"
      nil
    end

    def upload_attachment(base_path, document_name, extensions, content_type)
      file_path = find_attachment_file(base_path, document_name, extensions)
      return nil unless file_path

      url = upload_to_s3(file_path, content_type)
      @stats[:attachments] += 1
      url
    end

    # --- HTTP ---

    def post_chunk(payload, chunk_number, total_chunks)
      print "  Uploading chunk #{chunk_number}/#{total_chunks} to API... "

      uri = URI.parse(@api_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 30
      http.read_timeout = 120

      request = Net::HTTP::Post.new(uri.path)
      request["Authorization"] = "Bearer #{@token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        result = JSON.parse(response.body)
        stats = result["imported"]
        puts "OK (#{stats['documents']} docs, #{stats['articles']} articles, #{stats['embeddings']} embeddings)"
        @stats[:chunks_ok] += 1
      else
        puts "FAILED (#{response.code}: #{response.body.truncate(100)})"
        @stats[:chunks_failed] += 1
      end
    rescue StandardError => e
      puts "ERROR (#{e.message})"
      @stats[:chunks_failed] += 1
    end

    def print_summary
      puts ""
      puts "Upload import complete!"
      puts "  Chunks:      #{@stats[:chunks_ok]} successful, #{@stats[:chunks_failed]} failed"
      puts "  Documents:   #{@stats[:documents]}"
      puts "  Articles:    #{@stats[:articles]}"
      puts "  Embeddings:  #{@stats[:embeddings]}"
      puts "  Attachments: #{@stats[:attachments]} uploaded to S3"
    end
  end
end
