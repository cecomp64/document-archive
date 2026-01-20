class AddPaperclipAttachmentsToDocuments < ActiveRecord::Migration[7.1]
  def change
    # Remove the old URL columns
    remove_column :document_archive_documents, :pdf_url, :string
    remove_column :document_archive_documents, :txt_url, :string
    remove_column :document_archive_documents, :markdown_url, :string

    # Add Paperclip attachment columns for PDF
    add_column :document_archive_documents, :pdf_file_name, :string
    add_column :document_archive_documents, :pdf_content_type, :string
    add_column :document_archive_documents, :pdf_file_size, :bigint
    add_column :document_archive_documents, :pdf_updated_at, :datetime

    # Add Paperclip attachment columns for text
    add_column :document_archive_documents, :txt_file_name, :string
    add_column :document_archive_documents, :txt_content_type, :string
    add_column :document_archive_documents, :txt_file_size, :bigint
    add_column :document_archive_documents, :txt_updated_at, :datetime

    # Add Paperclip attachment columns for markdown
    add_column :document_archive_documents, :markdown_file_name, :string
    add_column :document_archive_documents, :markdown_content_type, :string
    add_column :document_archive_documents, :markdown_file_size, :bigint
    add_column :document_archive_documents, :markdown_updated_at, :datetime

    # Add Paperclip attachment columns for JSON (original data)
    add_column :document_archive_documents, :json_file_name, :string
    add_column :document_archive_documents, :json_content_type, :string
    add_column :document_archive_documents, :json_file_size, :bigint
    add_column :document_archive_documents, :json_updated_at, :datetime
  end
end
