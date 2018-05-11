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
                   new_item(:i21, "Nested", open: false)
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

  describe "#change_items" do
  end

  describe "#open_items_ids" do
    it "returns array of ids for expanded items" do
      allow(Yast::UI).to receive(:QueryWidget).and_return(i2: "ID")
      expect(subject.open_items_ids).to eq [:i2]
    end
  end
end
