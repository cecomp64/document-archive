module DocumentArchive
  class Document < ApplicationRecord
    has_many :articles, dependent: :destroy

    has_one_attached :pdf
    has_one_attached :txt
    has_one_attached :markdown
    has_one_attached :json

    def has_attachments?
      pdf.attached? || txt.attached? || markdown.attached?
    end

    def attachment_formats
      formats = []
      formats << :pdf if pdf.attached?
      formats << :txt if txt.attached?
      formats << :markdown if markdown.attached?
      formats
    end

    def pdf_url
      attachment_url(pdf)
    end

    def txt_url
      attachment_url(txt)
    end

    def markdown_url
      attachment_url(markdown)
    end

    def json_url
      attachment_url(json)
    end

    private

    def attachment_url(attachment)
      return nil unless attachment.attached?

      if Rails.application.config.active_storage.service == :amazon
        attachment.url
      else
        Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
      end
    end
  end
end
