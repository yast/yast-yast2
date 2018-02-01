#!/usr/bin/env rspec

require_relative "../test_helper"
require "y2packager/release_notes"

describe Y2Packager::ReleaseNotes do
  subject(:rn) do
    described_class.new(
      product_name: "SLES", content: "", user_lang: user_lang, lang: "en_US",
      format: format, version: version
    )
  end

  let(:user_lang) { "de_DE" }
  let(:format) { :txt }
  let(:version) { "15.0" }

  describe "#matches?" do
    context "when language, format and version match" do
      it "returns true" do
        expect(rn.matches?(user_lang, format, version)).to eq(true)
      end
    end

    context "when language does not match" do
      it "returns false" do
        expect(rn.matches?("cs_CZ", format, version)).to eq(false)
      end
    end

    context "when format does not match" do
      it "returns false" do
        expect(rn.matches?(user_lang, :rtf, version)).to eq(false)
      end
    end

    context "when version does not match" do
      it "returns false" do
        expect(rn.matches?(user_lang, format, "12.3")).to eq(false)
      end
    end

    context "when everything matches but version is :latest" do
      let(:version) { :latest }

      it "returns true" do
        expect(rn.matches?(user_lang, format, "12.3")).to eq(true)
      end
    end
  end
end
