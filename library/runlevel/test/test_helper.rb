require 'rspec'

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

Yast.import 'Service'

# We need the stubs used for SystemdService tests
require_relative "../../systemd/test/test_helper"

