#! /usr/bin/ruby

ENV["Y2DIR"] = File.expand_path("#{__dir__}/../src")
require "yast"
require "y2user/configuration"

configuration = Y2User::Configuration.system
puts configuration.inspect

configuration.users.each do |user|
  puts user.name + ": " + user.groups.map(&:name).join(", ")
end

res = configuration.clone_as(:staging)
puts configuration.users.size.inspect
puts res.users.size.inspect
