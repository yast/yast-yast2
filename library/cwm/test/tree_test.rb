#! /usr/bin/env rspec --format doc

require_relative "test_helper"

require "cwm/rspec"
require "cwm/tree"

describe CWM::Tree do
  class TestTree < CWM::Tree
    def label
      "my tree"
    end

    def items
      [
        new_item(:i1, "First", icon: "1st.png", open: false),
        new_item(:i2, "Second", open: true, children: [
                   new_item(:i21, "Nested")
                 ])
      ]
    end
  end

  subject { TestTree.new }

  include_examples "CWM::CustomWidget"

  describe "#items" do
  end

  describe "#items=" do
  end

  describe "change_items" do
  end
end
