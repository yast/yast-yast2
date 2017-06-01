#! /usr/bin/env rspec

require_relative "test_helper"

require "cwm/wrapper_widget"

describe CWM::WrapperWidget do
  describe "#cwm_definition" do
    it "returns passed hash content" do
      content = { "test" => "test" }
      expect(described_class.new("test", content).cwm_definition).to eq content
    end
  end

  describe "#widget_id" do
    it "returns passed widget id" do
      content = { "test" => "test" }
      expect(described_class.new("test", content).widget_id).to eq "test"
    end
  end
end
