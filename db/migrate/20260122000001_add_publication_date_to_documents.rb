class AddPublicationDateToDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :document_archive_documents, :publication_date, :date
    add_index :document_archive_documents, :publication_date
  end
end
