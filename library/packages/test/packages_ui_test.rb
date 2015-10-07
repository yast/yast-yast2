#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "PackagesUI"

describe Yast::PackagesUI do
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
end
