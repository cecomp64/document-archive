Rails.application.routes.draw do
  mount Document::Archive::Engine => "/document-archive"
end
