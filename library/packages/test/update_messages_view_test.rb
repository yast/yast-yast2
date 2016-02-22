#!/usr/bin/env rspec

require_relative "test_helper"
require "packages/update_message"
require "packages/update_messages_view"

describe Packages::UpdateMessagesView do
  subject(:view) { Packages::UpdateMessagesView.new(messages) }

  let(:messages) {
    [
      Packages::UpdateMessage.new("pkg1", "message 1", "/var/adm/path-1", "/var/adm/path-1"),
      Packages::UpdateMessage.new("pkg2", "message 2", "/var/adm/path-2", "/var/adm/path-2")
    ]
  }

  describe "#richtext" do
    it "concatenates information of all messages in a richtext string" do
      expect(view.richtext)
        .to eq("<h1>Packages messages</h1><h2>pkg1</h2><p><em>This message will be available at /var/adm/path-1</em></p><br>message 1<hr>" \
               "<h2>pkg2</h2><p><em>This message will be available at /var/adm/path-2</em></p><br>message 2")
    end
  end
end
