module DocumentArchive
  class Embedding < ApplicationRecord
    belongs_to :article

    has_neighbors :vector

    validates :vector, presence: true
  end
end
