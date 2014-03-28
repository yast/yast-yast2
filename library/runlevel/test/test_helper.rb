#!/usr/bin/env rspec

require 'rspec'

require "yast"

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

Yast.import 'Service'

# We need the stubs used for SystemdService tests
require_relative "../../systemd/test/test_helper"

