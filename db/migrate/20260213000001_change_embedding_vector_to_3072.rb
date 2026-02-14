class ChangeEmbeddingVectorTo3072 < ActiveRecord::Migration[7.1]
  def change
    remove_index :document_archive_embeddings, :vector, name: "index_document_archive_embeddings_on_vector"

    change_column :document_archive_embeddings, :vector, :vector, limit: 3072

    add_index :document_archive_embeddings,
              :vector,
              using: :hnsw,
              opclass: :vector_cosine_ops,
              name: "index_document_archive_embeddings_on_vector"
  end
end
