#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Report"
Yast.import "Popup"

describe Yast::Report do
  subject(:report) { Yast::Report }

  describe ".multi_messages" do
    DummyMessage = Struct.new(:title, :body)

    let(:messages) { (1..2).map { |n| DummyMessage.new("Title #{n}", "Body #{n}") } }

    it "stores and log the messages" do
      allow(Yast::Popup).to receive(:multi_messages)
      report.multi_messages("Installation", messages)
      expect(Yast::Report.GetMessages(false, false, true, false))
        .to match(/Title 1.+Body 1.+Title 2.+Body 2/)
    end

    context "if 'display_messages' is enabled" do
      before { Yast::Report.DisplayMessages(true, 0) }

      it "shows a popup" do
        expect(Yast::Popup).to receive(:multi_messages).with("Installation", messages, timeout: false)
        report.multi_messages("Installation", messages)
      end
    end

    context "if 'display_messages' is not enabled" do
      before { Yast::Report.DisplayMessages(false, 0) }

      it "does not show a popup" do
        expect(Yast::Popup).to_not receive(:multi_messages)
        report.multi_messages("Installation", messages)
      end
    end

    context "if a timeout for messages is set" do
      before { Yast::Report.DisplayMessages(true, 5) }

      it "does shows a popup with a timeout" do
        expect(Yast::Popup).to receive(:multi_messages).with("Installation", messages, timeout: 5)
        report.multi_messages("Installation", messages)
      end
    end
  end
end
