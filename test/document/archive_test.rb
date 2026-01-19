require "test_helper"

class Document::ArchiveTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert Document::Archive::VERSION
  end
end
