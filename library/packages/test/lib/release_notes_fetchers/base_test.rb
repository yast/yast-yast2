#!/usr/bin/env rspec

require_relative "../../test_helper"
require "y2packager/release_notes_fetchers/rpm"
require "y2packager/product"
require "y2packager/release_notes_content_prefs"

describe Y2Packager::ReleaseNotesFetchers::Base do
  subject(:fetcher) { described_class.new(product) }

  let(:product) { instance_double(Y2Packager::Product, name: "dummy") }

  describe "#latest_version" do
    it "raises NotImplementedError" do
      expect { fetcher.latest_version }.to raise_error(NotImplementedError)
    end
  end

  describe "#release_notes" do
    let(:prefs) { double(Y2Packager::ReleaseNotesContentPrefs) }

    it "raises NotImplementedError" do
      expect { fetcher.release_notes(prefs) }.to raise_error(NotImplementedError)
    end
  end
end
