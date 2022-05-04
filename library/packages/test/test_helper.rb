require_relative "../../../test/test_helper"
require "pathname"

PACKAGES_FIXTURES_PATH = Pathname.new(File.dirname(__FILE__)).join("data")

LIBS_TO_SKIP = [
  "y2packager/product_spec" # used in SlideShow.rb
].freeze

# Hack to avoid to require some files. Stolen from
# https://github.com/yast/yast-storage-ng/blob/master/test/spec_helper.rb#L32-L50
#
# This is here to avoid a cyclic dependency with yast2-packager at build time.
# yast2.spec does build-require yast2-packager, so the (Ruby) require for files
# defined by that package must be avoided.
#
# Of course that means that tests might need to use instance() or
# instance_double() to make the missing classes and methods from those
# libraries available.
#
# Notice that the problem might be hidden for locally running the unit tests,
# but not when calling them in an Autobuild environment (e.g. "rake osc:build"
# or "rake osc:sr").
module Kernel
  alias_method :old_require, :require

  def require(path)
    old_require(path) unless LIBS_TO_SKIP.include?(path)
  end
end
