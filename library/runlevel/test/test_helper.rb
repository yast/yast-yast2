require 'rspec'

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

# We need the stubs used for SystemdService tests
require_relative "../../systemd/test/test_helper"

