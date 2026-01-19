DocumentArchive::Engine.routes.draw do
  root "static_pages#index"

  namespace :api do
    get "stats", to: "stats#show"
    get "articles", to: "articles#index"
    post "search-text", to: "search#search_text"
  end
end
