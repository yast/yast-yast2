#!/usr/bin/env rspec

require_relative "../../test_helper"
require "y2packager/release_notes_fetchers/rpm"
require "y2packager/product"

describe Y2Packager::ReleaseNotesFetchers::Rpm do
  subject(:fetcher) { described_class.new(product) }

  let(:product) { instance_double(Y2Packager::Product, name: "dummy") }
  let(:package) { Y2Packager::Package.new("release-notes-dummy", 2, "15.1") }
  let(:dependencies) do
    [
      { "deps" => [{ "provides" => "release-notes() = dummy" }] }
    ]
  end

  let(:provides) do
    [["release-notes-dummy", :CAND, :NONE]]
  end

  let(:packages) { [package] }
  let(:user_lang) { "en_US" }
  let(:format) { :txt }
  let(:fallback_lang) { "en" }
  let(:prefs) { Y2Packager::ReleaseNotesContentPrefs.new(user_lang, fallback_lang, format) }

  before do
    allow(Yast::Pkg).to receive(:PkgQueryProvides).with("release-notes()")
      .and_return(provides)
    allow(Yast::Pkg).to receive(:ResolvableDependencies)
      .with("release-notes-dummy", :package, "").and_return(dependencies)
    allow(Y2Packager::Package).to receive(:find).with(package.name)
      .and_return(packages)
    allow(package).to receive(:download_to) do |path|
      ::FileUtils.cp(FIXTURES_PATH.join("release-notes-dummy.rpm"), path)
    end
    allow(package).to receive(:status).and_return(:available)
  end

  describe "#release_notes" do
    it "cleans up temporary files" do
      dir = Dir.mktmpdir
      allow(Dir).to receive(:mktmpdir).and_return(dir)
      fetcher.release_notes(prefs)
      expect(File).to_not be_directory(dir)
    end

    context "when a full language code is given (xx_XX)" do
      it "returns product release notes for the given language" do
        rn = fetcher.release_notes(prefs)
        expect(rn.content).to eq("Release Notes\n")
        expect(rn.lang).to eq("en")
        expect(rn.user_lang).to eq("en_US")
      end

      context "and release notes are not available" do
        let(:user_lang) { "de_DE" }

        it "returns product release notes for the short language code (xx)" do
          rn = fetcher.release_notes(prefs)
          expect(rn.content).to eq("Versionshinweise\n")
          expect(rn.lang).to eq("de")
          expect(rn.user_lang).to eq("de_DE")
        end
      end
    end

    context "when a format is given" do
      let(:format) { :html }

      it "returns product release notes in the given format" do
        rn = fetcher.release_notes(prefs)
        expect(rn.content).to eq("<h1>Release Notes</h1>\n")
        expect(rn.format).to eq(:html)
      end

      context "and release notes are not available in the given format" do
        let(:user_lang) { "de_DE" }
        let(:format) { :html }

        it "returns the English version" do
          rn = fetcher.release_notes(prefs)
          expect(rn.content).to eq("<h1>Release Notes</h1>\n")
          expect(rn.format).to eq(:html)
        end
      end
    end

    context "when no package containing release notes was found" do
      let(:provides) { [] }

      it "returns nil" do
        expect(fetcher.release_notes(prefs)).to be_nil
      end
    end

    context "when more than one package provides release notes" do
      let(:provides) do
        [
          ["release-notes-more-dummy", :CAND, :NONE],
          ["release-notes-dummy", :CAND, :NONE]
        ]
      end

      it "uses the first in alphabetical order" do
        expect(Y2Packager::Package).to receive(:find)
          .with("release-notes-dummy").and_return([package])
        expect(Y2Packager::Package).to_not receive(:find)
          .with("release-notes-more-dummy")
        fetcher.release_notes(prefs)
      end
    end

    context "when there is more than one package version" do
      let(:other_package) { Y2Packager::Package.new("release-notes-dummy", 2, "15.0") }
      let(:packages) { [other_package, package] }

      before do
        allow(other_package).to receive(:status).and_return(:selected)
      end

      it "selects the latest one" do
        rn = fetcher.release_notes(prefs)
        expect(rn.version).to eq("15.1")
      end
    end

    context "when release package is not available/selected" do
      before do
        allow(package).to receive(:status).and_return(:removed)
      end

      it "ignores the package" do
        expect(fetcher.release_notes(prefs)).to be_nil
      end
    end
  end

  describe "#latest_version" do
    it "returns latest version from release notes package" do
      expect(fetcher.latest_version).to eq(package.version)
    end

    context "when no release notes package was found" do
      before do
        allow(fetcher).to receive(:release_notes_package).and_return(nil)
      end

      it "returns :none" do
        expect(fetcher.latest_version).to eq(:none)
      end
    end
  end
end
