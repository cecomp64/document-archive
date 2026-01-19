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

### Data Import

The `document_archive:import` rake task imports JSON files with this structure:
- Main files: `{ "documents": [...], "articles": [...] }`
- Embedding files: `*-embeddings.json` with `{ "embeddings": [{ "articleId": "...", "vector": [...] }] }`

## Environment Variables

Required in `.env` or compose.yaml:
- `GEMINI_API_KEY` - Google Gemini API key for embedding generation
- `DATABASE_HOST`, `DATABASE_USER`, `DATABASE_PASSWORD` - PostgreSQL connection
