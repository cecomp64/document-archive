# DocumentArchive

A Rails Engine gem that provides semantic search over documents and articles using vector embeddings. It uses PostgreSQL with pgvector for vector similarity search and Google Gemini API for embedding generation.

## Features

- Semantic search using vector embeddings (768-dimensional vectors with HNSW indexing)
- Document and article management with UUID primary keys
- PostgreSQL with pgvector for efficient similarity search
- Google Gemini API integration for embedding generation
- RESTful API endpoints for search and data access
- Import/export functionality for data migration between environments
- Publication date support with year-based filtering across all views
- Documents sorted and grouped by publication year
- Clickable category and keyword tags for quick filtering

## Installation

Add this line to your application's Gemfile:

```ruby
gem "document-archive"
```

And then execute:

```bash
$ bundle install
```

### Requirements

- Ruby on Rails >= 7.1.5.2
- PostgreSQL with pgvector extension
- Google Gemini API key (for embedding generation)

### Mount the Engine

In your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount DocumentArchive::Engine => "/document_archive"
end
```

### Run Migrations

```bash
$ bin/rails document_archive:install:migrations
$ bin/rails db:migrate
```

### Environment Variables

Configure the following environment variables:

| Variable | Description |
|----------|-------------|
| `GEMINI_API_KEY` | Google Gemini API key for embedding generation |
| `DATABASE_HOST` | PostgreSQL host |
| `DATABASE_USER` | PostgreSQL username |
| `DATABASE_PASSWORD` | PostgreSQL password |
| `IMPORT_API_TOKEN` | Secret token for the `/api/import` endpoint (required for API imports) |

## Usage

### API Endpoints

The engine provides the following API endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/stats` | GET | Returns document, article, and embedding counts |
| `/api/documents` | GET | Paginated document list with year grouping |
| `/api/articles` | GET | Paginated article list |
| `/api/search-text` | POST | Vector similarity search (requires `GEMINI_API_KEY`) |
| `/api/search-keywords` | POST | Search articles by keywords |
| `/api/search-categories` | POST | Search articles by categories |
| `/api/search-summary` | POST | Search articles by summary text |
| `/api/import` | POST | Import documents, articles, and embeddings (requires `IMPORT_API_TOKEN`) |
| `/api/import-embeddings` | POST | Update embeddings for existing articles (requires `IMPORT_API_TOKEN`) |

#### Filtering Parameters

All list and search endpoints support year-based filtering:

| Parameter | Description |
|-----------|-------------|
| `start_year` | Filter results to documents published on or after this year |
| `end_year` | Filter results to documents published on or before this year |

The `/api/documents` endpoint also supports:

| Parameter | Description |
|-----------|-------------|
| `group_by_year` | Set to `true` to group results by publication year |

The `/api/articles` endpoint also supports:

| Parameter | Description |
|-----------|-------------|
| `category` | Filter by exact category match |
| `keyword` | Filter by exact keyword match |

### Models

- **Document** - Container for articles, uses UUID primary key, has `publication_date` for sorting/filtering
- **Article** - Belongs to a document, stores content with JSONB for categories/keywords
- **Embedding** - Stores 768-dimensional vector for an article, uses HNSW index for cosine similarity search

### Web Interface

The engine provides a web interface with three main views:

- **Search** (`/`) - Semantic and text-based search with year filtering
- **Articles** (`/articles`) - Browse all articles with year and category/keyword filtering
- **Documents** (`/documents`) - Browse documents grouped by publication year

All views support filtering by publication year range. Articles display clickable category and keyword tags that link to filtered article lists.

## Data Import/Export

### File Formats

**Document/article files** (`*.json`, excluding `*-embeddings.json`):

```json
{
  "documents": [{ "id": "doc-uuid", ... }],
  "articles": [{ "id": "article-uuid", "documentId": "doc-uuid", ... }]
}
```

**Embedding files** (`*-embeddings.json`):

```json
{
  "embeddings": [
    { "articleId": "article-uuid", "vector": [0.1, 0.2, ...] }
  ]
}
```

Embedding files must be named to match their corresponding data file (e.g., `data.json` and `data-embeddings.json` in the same directory).

### 1. Seed a Local Database

Import documents, articles, and embeddings from JSON files on disk:

```bash
bin/rails "document_archive:import[/path/to/json/files]"
```

The task will:
- Process all `*.json` files in the directory (excluding `*-embeddings.json`)
- Import documents and articles from each file
- Automatically import the matching `*-embeddings.json` file if it exists
- Attach any PDF, TXT, and Markdown files found alongside the JSON

With Docker:

```bash
docker compose exec app bin/rails "document_archive:import[/path/to/json/files]"
```

### 2. Seed a Remote Database From a Local One

For environments without filesystem access (e.g., Heroku), first export the data to chunked JSON files, then upload via the API.

**Step 1: Export locally**

```bash
# Export to chunked JSON files (10 documents per chunk by default)
bin/rails "document_archive:export[export,10]"
```

This generates `export/chunk_000.json`, `chunk_001.json`, etc. Each chunk contains documents with S3 URLs for attachments (valid for 7 days), plus their associated articles and embeddings.

With Docker, export and then copy to the host:

```bash
docker compose exec app bin/rails "document_archive:export[export,10]"
docker compose cp app:/rails/test/dummy/export/. ./export/
```

**Step 2: Upload to remote**

```bash
export IMPORT_API_TOKEN=your-secret-token

bin/rails "document_archive:upload_chunks[export,https://your-app.example.com/document_archive/api/import]"
```

Or manually with curl:

```bash
for f in export/chunk_*.json; do
  curl -X POST https://your-app.example.com/document_archive/api/import \
    -H "Authorization: Bearer $IMPORT_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d @$f
done
```

### 3. Update Embeddings on a Local Database

To replace embeddings for existing articles (e.g., after switching embedding models), use the `reimport_embeddings` task. This matches articles by UUID and updates or creates embeddings without touching documents or articles.

```bash
bin/rails "document_archive:reimport_embeddings[/path/to/embeddings]"
```

The task accepts any directory structure — it recursively finds all `*.json` files containing an `"embeddings"` key.

With Docker:

```bash
docker compose exec app bin/rails "document_archive:reimport_embeddings[/path/to/embeddings]"
```

### 4. Update Embeddings on a Remote Database

Upload embedding files to the `import-embeddings` API endpoint. The rake task recursively finds all `*-embeddings.json` files in the given directory and uploads each one.

```bash
export IMPORT_API_TOKEN=your-secret-token

bin/rails "document_archive:upload_embeddings[/path/to/embeddings,https://your-app.example.com/document_archive/api/import-embeddings]"
```

Or manually with curl:

```bash
for f in /path/to/embeddings/*-embeddings.json; do
  curl -X POST https://your-app.example.com/document_archive/api/import-embeddings \
    -H "Authorization: Bearer $IMPORT_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d @$f
done
```

Both the local and remote re-import will update existing embeddings if the article already has one, or create a new embedding if it doesn't. Articles are matched by their UUID.

## Development

### Docker Setup (Recommended)

```bash
# Start PostgreSQL and the app
docker compose up -d

# Run migrations
docker compose exec app bin/rails db:migrate

# Run tests
docker compose exec app bin/rails test

# Install gems
docker compose run --rm app bundle install

# Import data
docker compose exec app bin/rails "document_archive:import[/path/to/json/files]"

# Database access
docker compose exec db psql -U root -d document_archive_development
```

The app runs at `http://localhost:3100` (port 3100 maps to internal 3000).

### Export with Docker

```bash
# Export to chunked JSON files
docker compose exec app bin/rails "document_archive:export[export,5]"

# Copy chunks to local machine
docker compose cp app:/rails/test/dummy/export/. ./export/
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/cecomp64/document-archive.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
