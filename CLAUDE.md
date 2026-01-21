# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DocumentArchive is a Rails Engine gem that provides semantic search over documents and articles using vector embeddings. It uses PostgreSQL with pgvector for vector similarity search and Google Gemini API for embedding generation.

## Development Commands

```bash
# Docker development (primary workflow)
docker compose up -d                              # Start PostgreSQL and app
docker compose exec app bin/rails db:migrate     # Run migrations
docker compose exec app bin/rails test           # Run tests
docker compose run --rm app bundle install       # Install gems

# Import data from JSON files
docker compose exec app bin/rails "document_archive:import[/path/to/json/files]"

# Database access
docker compose exec db psql -U root -d document_archive_development
```

App runs at `http://localhost:3100` (port 3100 maps to internal 3000).

## Architecture

### Rails Engine Structure

This is a mountable Rails engine under the `DocumentArchive` namespace. The dummy app in `test/dummy/` is used for development and testing.

### Models

- **Document** → has_many Articles (UUID primary key)
- **Article** → belongs_to Document, has_one Embedding (UUID primary key, JSONB for categories/keywords)
- **Embedding** → belongs_to Article (1536-dim vector with HNSW index for cosine similarity)

### API Endpoints (mounted at root in dummy app)

- `GET /api/stats` - Document/article/embedding counts
- `GET /api/articles?limit=&offset=` - Paginated article list
- `POST /api/search-text` - Vector similarity search (requires GEMINI_API_KEY)

### Key Services

**GeminiEmbeddingService** (`app/services/document_archive/`) - Calls Google's text-embedding-004 model to generate embeddings for search queries.

### Data Import/Export

**Local file import** - The `document_archive:import` rake task imports JSON files with this structure:
- Main files: `{ "documents": [...], "articles": [...] }`
- Embedding files: `*-embeddings.json` with `{ "embeddings": [{ "articleId": "...", "vector": [...] }] }`

**Export for remote import** - For importing to environments without filesystem access (e.g., Heroku):

```bash
# Export to chunked JSON files (5 documents per chunk by default)
docker compose exec app bin/rails "document_archive:export[export,5]"

# Copy chunks to local machine
docker compose cp app:/rails/test/dummy/export/. ./export/
```

This generates `export/chunk_000.json`, `chunk_001.json`, etc. Each chunk contains documents with S3 URLs for attachments (valid for 7 days), plus their associated articles and embeddings.

**API import** - Import chunks via HTTP to remote environments:

```bash
# Set the import token on the target app
export IMPORT_API_TOKEN=your-secret-token

# Import all chunks
for f in export/chunk_*.json; do
  echo "Importing $f..."
  curl -X POST https://your-app.herokuapp.com/document_archive/api/import \
    -H "Authorization: Bearer $IMPORT_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d @$f
done
```

## Environment Variables

Required in `.env` or compose.yaml:
- `GEMINI_API_KEY` - Google Gemini API key for embedding generation
- `DATABASE_HOST`, `DATABASE_USER`, `DATABASE_PASSWORD` - PostgreSQL connection
- `IMPORT_API_TOKEN` - Secret token for the `/api/import` endpoint (required on target app)
