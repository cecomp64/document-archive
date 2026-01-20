class AddAttachmentUrlsToArticles < ActiveRecord::Migration[7.1]
  def change
    add_column :document_archive_articles, :pdf_url, :string
    add_column :document_archive_articles, :txt_url, :string
    add_column :document_archive_articles, :markdown_url, :string
  end
end
