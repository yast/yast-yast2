top_srcdir = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{top_srcdir}/library/*/src")
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"
require_relative "../../general/test/SCRStub"

RSpec.configure do |c|
  c.include SCRStub
end
