namespace :document_archive do
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
      @stats = { documents: 0, articles: 0, embeddings: 0 }
    end

    def import
      puts "Starting import from #{@directory}..."

      json_files = Dir.glob(File.join(@directory, "*.json"))
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
      import_documents(data["documents"], document_name) if data["documents"]
      import_articles(data["articles"]) if data["articles"]

      embeddings_file = file.sub(".json", "-embeddings.json")
      import_embeddings(embeddings_file) if File.exist?(embeddings_file)
    end

    def import_documents(documents, document_name)
      documents.each do |doc_data|
        document = Document.create!(
          name: document_name
        )
        @document_id_map[doc_data["id"]] = document.id
        @stats[:documents] += 1
      end
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
      puts "  Documents: #{@stats[:documents]}"
      puts "  Articles:  #{@stats[:articles]}"
      puts "  Embeddings: #{@stats[:embeddings]}"
    end
  end
end
