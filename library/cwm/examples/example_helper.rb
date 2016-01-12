root_location = File.expand_path("../../../..", __FILE__)
inc_dirs = Dir.glob("#{root_location}/library/*/src")

ENV["Y2DIR"] = inc_dirs.join(":")

# fake adding load path as client already have yast loaded
inc_dirs.each do |dir|
  lib_dir = File.join(dir, "lib")
  $LOAD_PATH.unshift lib_dir if File.exist? lib_dir
end

require "yast"

Yast::Builtins.y2milestone("root location #{inc_dirs}")
Yast::Builtins.y2milestone("load path #{$LOAD_PATH}")
