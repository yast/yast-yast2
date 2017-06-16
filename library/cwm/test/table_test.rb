#! /usr/bin/env rspec --format doc

require_relative "test_helper"

require "cwm/rspec"
require "cwm/table"

describe CWM::Table do
  class MyTable < CWM::Table
    def header
      ["English", "Deutsch"]
    end

    def items
      [
        [:one, "one", "eins"],
        [:two, "two", "zwei"]
      ]
    end
  end
  subject { MyTable.new }

  include_examples "CWM::Table"
  include_examples "CWM::CustomWidget"
end
