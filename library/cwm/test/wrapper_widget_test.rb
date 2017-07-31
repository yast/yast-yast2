#! /usr/bin/env rspec

require_relative "test_helper"

require "cwm/wrapper_widget"

describe CWM::WrapperWidget do
  describe "#cwm_definition" do
    it "returns passed hash content" do
      content = { "test" => "value" }
      expect(described_class.new(content).cwm_definition["test"]).to eq "value"
    end

    it "return hash that has _cwm_key key with widget id" do
      content = { "test" => "value" }
      expect(described_class.new(content, id: "wid").cwm_definition["_cwm_key"]).to eq "wid"
    end
  end

  describe "#widget_id" do
    it "returns passed widget id" do
      content = { "test" => "value" }
      expect(described_class.new(content, id: "wid").widget_id).to eq "wid"
    end
  end
end
