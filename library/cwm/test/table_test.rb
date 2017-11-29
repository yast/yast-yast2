#! /usr/bin/env rspec --format doc

require_relative "test_helper"

require "cwm/rspec"
require "cwm/table"
Yast.import "UI"

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
  subject(:table) { MyTable.new }

  include_examples "CWM::Table"
  include_examples "CWM::CustomWidget"

  describe "#value=" do
    context "when called with a single id" do
      it "passes an array with only that id to UI.ChangeWidget" do
        expect(Yast::UI).to receive(:ChangeWidget).with(anything, anything, [:id])
        table.value = :id
      end
    end

    context "when called with an array of ids" do
      it "passes the same array to UI.ChangeWidget" do
        expect(Yast::UI).to receive(:ChangeWidget).with(anything, anything, [:id1, :id2])
        table.value = [:id1, :id2]
      end
    end
  end
end
