DocumentArchive::Engine.routes.draw do
  root "static_pages#index"

  get "articles", to: "static_pages#articles"
  get "documents", to: "static_pages#documents"
  get "documents/:id", to: "static_pages#document_show", as: :document

  namespace :api do
    get "stats", to: "stats#show"
    get "articles", to: "articles#index"
    get "documents", to: "documents#index"
    get "documents/:id", to: "documents#show"
    post "search-text", to: "search#search_text"
    post "search-keywords", to: "search#search_keywords"
    post "search-categories", to: "search#search_categories"
    post "search-summary", to: "search#search_summary"
  end
end
