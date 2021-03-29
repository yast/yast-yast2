#!/usr/bin/env rspec
# typed: false

require_relative "test_helper"
require "packages/update_message"
require "packages/update_messages_view"

describe Packages::UpdateMessagesView do
  subject(:view) { Packages::UpdateMessagesView.new(messages) }

  let(:messages) do
    [
      Packages::UpdateMessage.new("pkg1", "message 1", "/var/adm/path-1", "/var/adm/path-1"),
      Packages::UpdateMessage.new("pkg2", "message 2", "/var/adm/path-2", "/var/adm/path-2")
    ]
  end

  describe "#richtext" do
    it "concatenates information of all messages in a richtext string" do
      expect(view.richtext).to match(/message 1.*message 2/m)
    end
  end
end
