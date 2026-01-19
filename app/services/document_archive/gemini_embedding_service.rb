require "net/http"
require "json"

module DocumentArchive
  class GeminiEmbeddingService
    GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent"

    def initialize(api_key: nil)
      @api_key = api_key || ENV["GEMINI_API_KEY"]
    end

    def embed(text)
      raise "GEMINI_API_KEY not configured" if @api_key.blank?

      uri = URI("#{GEMINI_API_URL}?key=#{@api_key}")

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = {
        model: "models/text-embedding-004",
        content: {
          parts: [{ text: text }]
        }
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.code.to_i != 200
        error_body = JSON.parse(response.body) rescue { "error" => response.body }
        raise "Gemini API error: #{error_body["error"]}"
      end

      result = JSON.parse(response.body)
      result.dig("embedding", "values")
    end
  end
end
