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
      pdf.attached? ? pdf.url : nil
    end

    def txt_url
      txt.attached? ? txt.url : nil
    end

    def markdown_url
      markdown.attached? ? markdown.url : nil
    end

    def json_url
      json.attached? ? json.url : nil
    end
  end
end
