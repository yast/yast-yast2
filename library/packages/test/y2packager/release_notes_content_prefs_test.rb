#!/usr/bin/env rspec

require_relative "../test_helper"
require "y2packager/release_notes_content_prefs"

describe Y2Packager::ReleaseNotesContentPrefs do
  subject(:prefs) { described_class.new("es_ES", "en", :txt) }

  describe "#to_s" do
    it "returns a human readable representation" do
      expect(prefs.to_s).to eq(
        "content preferences: language 'es_ES', fallback language: 'en', and format 'txt'"
      )
    end
  end
end
