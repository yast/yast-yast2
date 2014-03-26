require 'rspec'

# We need the stubs used for SystemdService tests
require_relative "../../systemd/test/test_helper"

# And import the SystemdService before the Y2DIR change
Yast.import 'SystemdService'

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"


