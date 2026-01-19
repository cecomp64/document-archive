module DocumentArchive
  class Article < ApplicationRecord
    belongs_to :document
    has_one :embedding, dependent: :destroy

    validates :title, presence: true
  end
end
