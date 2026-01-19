class CreateDocumentArchiveArticles < ActiveRecord::Migration[7.1]
  def change
    create_table :document_archive_articles, id: :uuid do |t|
      t.references :document,
                   null: false,
                   foreign_key: { to_table: :document_archive_documents },
                   type: :uuid
      t.string :title, null: false
      t.text :summary
      t.jsonb :categories, default: []
      t.jsonb :keywords, default: []
      t.integer :page_start
      t.integer :page_end

      t.timestamps
    end

    add_index :document_archive_articles, :categories, using: :gin
    add_index :document_archive_articles, :keywords, using: :gin
  end
end
