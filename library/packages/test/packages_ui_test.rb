#!/usr/bin/env rspec

require_relative "test_helper"
require "packages/commit_result"
require "packages/update_message"

Yast.import "PackagesUI"

describe Yast::PackagesUI do
  subject(:packages_ui) { Yast::PackagesUI }

  describe "#format_license" do
    it "returns a preformatted HTML license unchanged" do
      license = "\n<!-- DT:Rich -->\n<h3>License Confirmation</h3>"
      expect(Yast::PackagesUI.format_license(license)).to eq(license)
    end

    it "converts a plain text into a rich text string" do
      license = "License Confirmation"
      expect(Yast::PackagesUI.format_license(license)).to match(/\A<p>.*<\/p>\z/)
    end

    it "escapes HTML tags in a plain text license" do
      license = "License & Patent Confirmation"
      expect(Yast::PackagesUI.format_license(license)).to include("&amp;")
    end

    it "converts two empty lines into paragraph separators" do
      license = "License Confirmation\n\nTerms and Conditions"
      expect(Yast::PackagesUI.format_license(license)).to match(/\A<p>.*<\/p><p>.*<\/p>\z/)
    end
  end

  describe "#show_update_messages" do
    let(:result) { [1, [], [], [], [message]] }
    let(:message) do
      { "solvable" => "mariadb", "text" => "message content",
        "installationPath" => "/some/path1", "currentPath" => "/some/path2" }
    end

    it "opens a popup containing update messages" do
      expect(Yast::Report).to receive(:LongMessage)
        .with(%r{<h2>mariadb</h2>})
      packages_ui.show_update_messages(result)
    end

    context "when no messages exist" do
      let(:result) { [0, [], [], [], []] }

      it "does not open a popup" do
        expect(Yast::Report).to_not receive(:LongMessage)
        packages_ui.show_update_messages(result)
      end
    end
  end
end
