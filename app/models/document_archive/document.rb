module DocumentArchive
  class Document < ApplicationRecord
    has_many :articles, dependent: :destroy
  end
end
