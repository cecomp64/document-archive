module Document
  module Archive
    class Engine < ::Rails::Engine
      isolate_namespace Document::Archive
    end
  end
end
