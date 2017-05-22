#! /usr/bin/env rspec --format doc

require_relative "test_helper"

require "cwm/rspec"
require "cwm/tree"

describe CWM::Tree do
  subject do
    CWM::Tree.new(
      [
        CWM::TreeItem.new(:i1, "First", icon: "1st.png", open: false),
        CWM::TreeItem.new(:i2, "Second", open: true, children: [
                            CWM::TreeItem.new(:i21, "Nested")
                          ])
      ], label: "my tree"
    )
  end

  include_examples "CWM::CustomWidget"

  describe "#items" do
  end

  describe "#items=" do
  end

  describe "change_items" do
  end
end
