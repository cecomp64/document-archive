class MoveAttachmentUrlsToDocuments < ActiveRecord::Migration[7.1]
  def change
    # Add to documents
    add_column :document_archive_documents, :pdf_url, :string
    add_column :document_archive_documents, :txt_url, :string
    add_column :document_archive_documents, :markdown_url, :string

    # Remove from articles
    remove_column :document_archive_articles, :pdf_url, :string
    remove_column :document_archive_articles, :txt_url, :string
    remove_column :document_archive_articles, :markdown_url, :string
  end
end
