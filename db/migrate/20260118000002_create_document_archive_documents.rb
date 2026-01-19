class CreateDocumentArchiveDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :document_archive_documents, id: :uuid do |t|
      t.string :name

      t.timestamps
    end
  end
end
