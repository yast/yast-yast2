#!/usr/bin/env rspec

require_relative "../test_helper"

require "y2packager/license"

describe Y2Packager::License do
  let(:license) { Y2Packager::License.new(content: "dummy content") }

  describe "#content_for" do
    it "returns the license content for the given language if exists" do
      expect(license.content_for(described_class::DEFAULT_LANG)).to eq("dummy content")
    end

    it "returns nil if there is no content for the given language" do
      expect(license.content_for("es_ES")).to eq(nil)
    end
  end

  describe "#add_content_for" do
    it "adds a new translated content to the license" do
      expect(license.content_for("es_ES")).to eq(nil)
      expect(license.add_content_for("es_ES", "contenido ficticio"))
      expect(license.content_for("es_ES")).to eq("contenido ficticio")
    end
  end

  describe "#accept!" do
    it "marks the license as accepted" do
      expect(license.accepted?).to be(false)
      license.accept!
      expect(license.accepted?).to be(true)
    end
  end

  describe "#reject!" do
    it "marks the license as rejected" do
      license.accept!
      expect(license.accepted?).to be(true)
      license.reject!
      expect(license.accepted?).to be(false)
    end
  end

  describe "#accepted?" do
    it "returns whether the license has been accepted or not" do
      license.reject!
      expect(license.accepted?).to be(false)
      license.accept!
      expect(license.accepted?).to be(true)
    end
  end
end
