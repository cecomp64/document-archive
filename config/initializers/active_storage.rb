## Add a prefix to all ActiveStorage blob keys for this engine
#Rails.configuration.to_prepare do
#  ActiveStorage::Blob.class_eval do
#    before_create :add_document_archive_prefix
#
#    private
#
#    def add_document_archive_prefix
#      self.key = "document_archive-#{Rails.env}/#{self.class.generate_unique_secure_token}"
#    end
#  end
#end
