class CreateDocumentArchiveEmbeddings < ActiveRecord::Migration[7.1]
  def change
    create_table :document_archive_embeddings do |t|
      t.references :article,
                   null: false,
                   foreign_key: { to_table: :document_archive_articles },
                   type: :uuid
      t.vector :vector, limit: 1536

      t.timestamps
    end

    add_index :document_archive_embeddings,
              :vector,
              using: :hnsw,
              opclass: :vector_cosine_ops,
              name: "index_document_archive_embeddings_on_vector"
  end
end
