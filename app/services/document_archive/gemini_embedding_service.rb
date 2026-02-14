require "net/http"
require "json"

module DocumentArchive
  class GeminiEmbeddingService
    BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
    DEFAULT_MODEL = "gemini-embedding-001"
    OUTPUT_DIMENSIONALITY = 768

    attr_reader :model_name

    def initialize(api_key: nil)
      @api_key = api_key || ENV["GEMINI_API_KEY"]
      @model = nil
      @model_name = nil
    end

    def embed(text)
      raise "GEMINI_API_KEY not configured" if @api_key.blank?

      model = resolve_model
      response = call_embed_api(model, text)

      if response.code.to_i == 404 && @model.nil?
        Rails.logger.warn("Gemini model '#{model}' not found, discovering available embedding models...")
        @model = discover_embedding_model
        @model_name = @model
        response = call_embed_api(@model, text)
      end

      if response.code.to_i != 200
        error_body = JSON.parse(response.body) rescue { "error" => response.body }
        raise "Gemini API error: #{error_body["error"]}"
      end

      result = JSON.parse(response.body)
      result.dig("embedding", "values")
    end

    private

    def resolve_model
      resolved = @model || DEFAULT_MODEL
      @model_name = resolved
      resolved
    end

    def call_embed_api(model, text)
      uri = URI("#{BASE_URL}/models/#{model}:embedContent?key=#{@api_key}")

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = {
        model: "models/#{model}",
        content: {
          parts: [{ text: text }]
        },
        output_dimensionality: OUTPUT_DIMENSIONALITY
      }.to_json

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
    end

    def discover_embedding_model
      uri = URI("#{BASE_URL}/models?key=#{@api_key}")
      response = Net::HTTP.get_response(uri)

      if response.code.to_i != 200
        raise "Failed to list Gemini models: HTTP #{response.code}"
      end

      models = JSON.parse(response.body)["models"] || []
      embedding_models = models.select do |m|
        supported = m["supportedGenerationMethods"] || []
        supported.include?("embedContent")
      end

      if embedding_models.empty?
        available = models.map { |m| m["name"] }.join(", ")
        raise "No embedding models available. Models found: #{available}"
      end

      # Prefer a model with "embedding" in the name, sorted by name descending to get latest version
      chosen = embedding_models
        .sort_by { |m| m["name"] }
        .reverse
        .find { |m| m["name"].include?("embedding") } || embedding_models.last

      model_id = chosen["name"].sub("models/", "")
      Rails.logger.info("Gemini: auto-selected embedding model '#{model_id}' from #{embedding_models.map { |m| m["name"] }.join(", ")}")
      model_id
    end
  end
end
