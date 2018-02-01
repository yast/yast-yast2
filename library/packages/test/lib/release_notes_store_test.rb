#!/usr/bin/env rspec

require_relative "../test_helper"
require "y2packager/release_notes_store"
require "y2packager/release_notes"

describe Y2Packager::ReleaseNotesStore do
  subject(:store) { described_class.new }

  let(:rn) do
    Y2Packager::ReleaseNotes.new(
      product_name: "SLES", content: "", user_lang: user_lang, lang: "en_US",
      format: format, version: version
    )
  end

  let(:user_lang) { "de_DE" }
  let(:format) { :txt }
  let(:version) { "15.0" }

  describe "#retrieve" do
    before do
      store.store(rn)
    end

    context "when release notes matching criteria are not stored" do
      it "returns nil" do
        expect(store.retrieve("SLES", user_lang, format, "12.3")).to be_nil
      end
    end

    context "when release notes matching criteria are stored" do
      it "returns release notes" do
        expect(store.retrieve("SLES", user_lang, format, version)).to eq(rn)
      end
    end
  end

  describe "#store" do
    it "stores release notes for later retrieval" do
      store.store(rn)
      expect(store.retrieve(rn.product_name, rn.user_lang, rn.format, rn.version))
        .to eq(rn)
    end

    context "when release notes for a given product are already defined" do
      before do
        store.store(old_rn)
      end

      context "and release notes to store are for the same product" do
        let(:old_rn) do
          Y2Packager::ReleaseNotes.new(
            product_name: "SLES", content: "", user_lang: user_lang, lang: "en_US",
            format: format, version: "12.3"
          )
        end

        it "replaces the previous version" do
          store.store(rn)

          expect(store.retrieve(rn.product_name, old_rn.user_lang, rn.format, rn.version))
            .to eq(rn)
          expect(store.retrieve(old_rn.product_name, rn.user_lang, old_rn.format, old_rn.version))
            .to be_nil
        end
      end

      context "and release notes to store are for a different product" do
        let(:old_rn) do
          Y2Packager::ReleaseNotes.new(
            product_name: "openSUSE", content: "", user_lang: user_lang, lang: "en_US",
            format: format, version: "12.3"
          )
        end

        it "keeps release notes if they are for another product" do
          store.store(rn)

          expect(store.retrieve(rn.product_name, old_rn.user_lang, rn.format, rn.version))
            .to eq(rn)
          expect(store.retrieve(old_rn.product_name, rn.user_lang, old_rn.format, old_rn.version))
            .to eq(old_rn)
        end
      end
    end
  end

  describe "#clear" do
    before do
      store.store(rn)
    end

    it "clears content" do
      store.clear
      expect(store.retrieve(rn.product_name, user_lang, format, version)).to be_nil
    end
  end
end
