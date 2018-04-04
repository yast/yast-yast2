#!/usr/bin/env rspec
# ------------------------------------------------------------------------------
# Copyright (c) 2018 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require_relative "../test_helper"

require "y2packager/license"

describe Y2Packager::License do
  subject(:license) { Y2Packager::License.new(fetcher) }

  let(:fetcher) do
    instance_double(Y2Packager::LicensesFetchers::Rpm, license_content: "license") 
  end

  before do
    described_class.clear_cache
    allow(Y2Packager::LicensesFetchers::Rpm).to receive(:new).and_return(fetcher)
  end

  describe ".find" do
    it "returns a license for the given product" do
      license = described_class.find("SLES", :rpm)
      expect(license).to be_a(Y2Packager::License)
    end

    context "when a license with the same ID was already retrieved" do
      it "returns the already retrieved instance" do
        sles_license = described_class.find("SLES", :rpm)
        sled_license = described_class.find("SLED", :rpm)
        expect(sles_license).to be(sled_license)
      end
    end

    context "when no license with the same ID was already retrieved" do
      before do
        allow(fetcher).to receive(:license_content).and_return("sles license", "sled license")
      end

      it "returns a new license instance" do
        sles_license = described_class.find("SLES", :rpm)
        sled_license = described_class.find("SLED", :rpm)
        expect(sles_license).to_not be(sled_license)
        expect(sles_license.id).to_not eq(sled_license.id)
      end
    end
  end

  describe "#id" do
    before do
      allow(fetcher).to receive(:license_content).and_return("content")
    end

    it "returns the license unique identifier" do
      expect(license.id).to eq("9a0364b9e99bb480dd25e1f0284c8555")
    end

    context "when the license is not found" do
      before do
        allow(fetcher).to receive(:license_content).and_return(nil)
      end

      it "returns nil" do
        expect(license.id).to be_nil
      end
    end
  end

  describe "#content_for" do
    let(:lang) { "es_ES" }

    context "when no language is given" do
      it "returns the license content for the default language" do
        expect(fetcher).to receive(:license_content).with(described_class::DEFAULT_LANG)
          .and_return("dummy content")
        expect(license.content_for).to eq("dummy content")
      end
    end

    it "returns the license content for the given language" do
      expect(fetcher).to receive(:license_content).with(lang)
        .and_return("dummy content")
      expect(license.content_for(lang)).to eq("dummy content")
    end

    context "when there is no translation for the given language" do
      before do
        allow(fetcher).to receive(:license_content).with(lang).and_return(nil)
        allow(fetcher).to receive(:license_content).with(described_class::DEFAULT_LANG)
          .and_return("dummy content")
      end

      it "returns the license content for the default language" do
        expect(license.content_for(lang)).to eq("dummy content")
      end
    end

    context "license content for the given languages was already retrieved" do
      before do
        allow(fetcher).to receive(:license_content).with(lang).and_return("content")
        license.content_for(lang)
      end

      it "returns cached content" do
        expect(fetcher).to_not receive(:license_content)
        expect(license.content_for(lang)).to eq("content")
      end
    end
  end

  describe "#add_content_for" do
    it "adds a new translated content to the license" do
      expect(license.add_content_for("es_ES", "contenido ficticio"))
      expect(license.content_for("es_ES")).to eq("contenido ficticio")
    end
  end

  describe "#locales" do
    before do
      allow(fetcher).to receive(:license_locales).and_return(["en_US", "cz_CZ"])
    end

    it "returns list of available translations for the license" do
      expect(license.locales).to eq(["en_US", "cz_CZ"])
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
