#!/usr/bin/env rspec

require_relative "../test_helper"
require "y2packager/release_notes_reader"
require "y2packager/release_notes_content_prefs"
require "y2packager/product"

describe Y2Packager::ReleaseNotesReader do
  subject(:reader) { described_class.new(product) }

  let(:product) { instance_double(Y2Packager::Product, name: "dummy") }

  let(:release_notes_store) do
    instance_double(Y2Packager::ReleaseNotesStore, clear: nil, retrieve: nil, store: nil)
  end

  let(:release_notes) do
    Y2Packager::ReleaseNotes.new(
      product_name: product.name,
      content:      "Release Notes\n",
      user_lang:    "en_US",
      lang:         "en_US",
      format:       :txt,
      version:      "15.0"
    )
  end

  let(:relnotes_from_url) do
    Y2Packager::ReleaseNotes.new(
      product_name: product.name,
      content:      "Release Notes\n",
      user_lang:    "en_US",
      lang:         "en_US",
      format:       :txt,
      version:      :latest
    )
  end

  let(:rpm_reader) do
    instance_double(
      Y2Packager::ReleaseNotesFetchers::Rpm,
      latest_version: "15.0",
      release_notes:  release_notes
    )
  end

  let(:url_reader) do
    instance_double(
      Y2Packager::ReleaseNotesFetchers::Url,
      latest_version: :latest,
      release_notes:  relnotes_from_url
    )
  end

  let(:registration) { double("Registration::Registration", is_registered?: registered?) }

  before do
    allow(Y2Packager::ReleaseNotesStore).to receive(:current)
      .and_return(release_notes_store)
    allow(Y2Packager::ReleaseNotesFetchers::Rpm).to receive(:new)
      .with(product).and_return(rpm_reader)
    allow(Y2Packager::ReleaseNotesFetchers::Url).to receive(:new)
      .with(product).and_return(url_reader)
  end

  describe "#release_notes" do
    let(:registered?) { true }

    before do
      stub_const("Registration::Registration", registration)
      allow(reader).to receive(:require).with("registration/registration")
    end

    context "when system is registered" do
      let(:registered) { true }

      it "retrieves release notes from RPM packages" do
        expect(rpm_reader).to receive(:release_notes).with(
          Y2Packager::ReleaseNotesContentPrefs.new("de_DE", "en", :txt)
        )
        rn = reader.release_notes(user_lang: "de_DE", format: :txt)
        expect(rn).to eq(release_notes)
      end

      context "when release notes are not found" do
        let(:release_notes) { nil }

        it "tries to get release notes from the relnotes_url property" do
          expect(rpm_reader).to receive(:release_notes).with(
            Y2Packager::ReleaseNotesContentPrefs.new("de_DE", "en", :html)
          )
          rn = reader.release_notes(user_lang: "de_DE", format: :html)
          expect(rn).to eq(relnotes_from_url)
        end
      end
    end

    context "when system is not registered" do
      let(:registered?) { false }

      it "retrieves release notes from external sources" do
        expect(url_reader).to receive(:release_notes).with(
          Y2Packager::ReleaseNotesContentPrefs.new("cs_CZ", "en", :txt)
        )
        rn = reader.release_notes(user_lang: "cs_CZ", format: :txt)
        expect(rn).to eq(relnotes_from_url)
      end

      context "when release notes are not found" do
        let(:relnotes_from_url) { nil }

        it "tries to get release notes from RPM packages" do
          expect(url_reader).to receive(:release_notes).with(
            Y2Packager::ReleaseNotesContentPrefs.new("cs_CZ", "en", :html)
          )
          rn = reader.release_notes(user_lang: "cs_CZ", format: :html)
          expect(rn).to eq(release_notes)
        end
      end
    end

    context "when no registration support is available" do
      before do
        expect(reader).to receive(:require).with("registration/registration")
          .and_raise(LoadError)
      end

      it "retrieves release notes from external sources" do
        rn = reader.release_notes(user_lang: "en_US", format: :txt)
        expect(rn).to eq(relnotes_from_url)
      end

      context "when release notes are not found" do
        let(:relnotes_from_url) { nil }

        it "tries to get release notes from RPM packages" do
          rn = reader.release_notes(user_lang: "en_US", format: :txt)
          expect(rn).to eq(release_notes)
        end
      end
    end

    it "stores the result for later retrieval" do
      expect(release_notes_store).to receive(:store)
        .with(release_notes)
      reader.release_notes
    end

    context "when the release notes were already downloaded" do
      let(:relnotes) { instance_double(Y2Packager::ReleaseNotes) }

      before do
        allow(release_notes_store).to receive(:retrieve)
          .and_return(release_notes)
      end

      it "does not download them again" do
        expect(reader.release_notes).to eq(release_notes)
      end

      it "does not try to store the result" do
        expect(release_notes_store).to_not receive(:store)
        expect(reader.release_notes).to eq(release_notes)
      end
    end
  end
end
