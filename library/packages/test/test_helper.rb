require_relative "../../../test/test_helper.rb"
require "pathname"

PACKAGES_FIXTURES_PATH = Pathname.new(File.dirname(__FILE__)).join("data")

# mock missing YaST modules
module Yast
  # we cannot depend on this module (circular dependency)
  class InstURLClass
    def installInf2Url(_extra_dir = "")
      ""
    end
  end

  InstURL = InstURLClass.new
end
