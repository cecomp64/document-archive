#require_relative "lib/document/archive/version"

Gem::Specification.new do |spec|
  spec.name        = "document-archive"
  spec.version     = "0.3.2" #Document::Archive::VERSION
  spec.authors     = ["Carl Svensson"]
  spec.email       = [""]
  spec.homepage    = "https://github.com/cecomp64/document-archive"
  spec.summary     = "A semantic search implementation and interface."
  spec.description = "Unlock the contents of your archived documents with semantic search capabilities powered by vector embeddings."

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/cecomp64/document-archive"
  #spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = `git ls-files -z`.split("\x0").select do |f|
    f.start_with?("app/", "config/", "db/", "lib/") || %w[MIT-LICENSE Rakefile README.md].include?(f)
  end

  spec.add_dependency "rails", ">= 7.1.5.2"
  spec.add_dependency "pg"
  spec.add_dependency "neighbor"
  spec.add_dependency "sprockets-rails"
  spec.add_dependency "aws-sdk-s3", "~> 1.0"
  spec.add_dependency "redcarpet"

  spec.add_development_dependency "puma"
  spec.add_development_dependency "dotenv-rails"
end
