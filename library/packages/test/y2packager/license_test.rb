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
  subject(:license) { Y2Packager::License.new(product_name: "SLES", fetcher: fetcher) }

  let(:content) { "Some license content" }
  let(:fetcher) do
    instance_double(Y2Packager::LicensesFetchers::Libzypp, content: "license", found?: true)
  end
  let(:handler) do
    instance_double(Y2Packager::LicensesHandlers::Libzypp)
  end

  before do
    described_class.clear_cache
    allow(Y2Packager::LicensesHandlers).to receive(:for).and_return(handler)
    allow(Y2Packager::LicensesFetchers::Libzypp).to receive(:new).and_return(fetcher)
  end

  describe ".find" do
    context "when some content is given" do
      before do
        allow(Y2Packager::License).to receive(:new)
          .with(product_name: "SLES", fetcher: fetcher, handler: handler, content: content)
          .and_return(license)
      end

      it "uses the content as license's content" do
        expect(described_class.find("SLES", content: content)).to be(license)
      end
    end

    context "when a license with the same ID was already retrieved" do
      it "returns the already retrieved instance" do
        sles_license = described_class.find("SLES")
        sled_license = described_class.find("SLED")

        expect(sles_license).to be(sled_license)
      end
    end

    context "when no license with the same ID was already retrieved" do
      before do
        allow(fetcher).to receive(:content).and_return("sles license", "sled license")
      end

      it "returns a new license instance" do
        sles_license = described_class.find("SLES")
        sled_license = described_class.find("SLED")

        expect(sles_license).to_not be(sled_license)
        expect(sles_license.id).to_not eq(sled_license.id)
      end
    end
  end

  describe "#id" do
    before do
      allow(fetcher).to receive(:content).and_return("content")
    end

    it "returns the license unique identifier" do
      expect(license.id).to eq("ed7002b439e9ac845f22357d822bac1444730fbdb6016d3ec9432297b9ec9f73")
    end

    context "when the license is not found" do
      before do
        allow(fetcher).to receive(:content).and_return(nil)
      end

      it "returns nil" do
        expect(license.id).to be_nil
      end
    end
  end

  describe "#content_for" do
    let(:czech_lang) { "cz_CZ" }
    let(:spanish_lang) { "es_ES" }
    let(:default_lang) { described_class::DEFAULT_LANG }

    let(:fetcher) { instance_double(Y2Packager::LicensesFetchers::Libzypp) }

    subject(:license) { Y2Packager::License.new(product_name: "SLES", fetcher: fetcher) }

    before do
      allow(fetcher).to receive(:content)
      allow(fetcher).to receive(:content).with(spanish_lang)
        .and_return("dummy content for Spanish language")
      allow(fetcher).to receive(:content).with(default_lang)
        .and_return("dummy content for default language")
    end

    context "when no language is given" do
      it "returns the license content for the default language" do
        expect(license.content_for).to eq("dummy content for default language")
      end
    end

    context "when a language is given" do
      it "returns the license content for the given language" do
        expect(license.content_for(spanish_lang)).to eq("dummy content for Spanish language")
      end

      context "but there is no translation for the given language" do
        it "returns nil" do
          expect(license.content_for(czech_lang)).to be_nil
        end
      end

      context "and license content for the given language was already retrieved" do
        before do
          license.content_for(spanish_lang)
        end

        it "returns cached content" do
          expect(fetcher).to_not receive(:content)
          expect(license.content_for(spanish_lang)).to eq("dummy content for Spanish language")
        end
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
    context "when there is a fetcher" do
      before do
        allow(fetcher).to receive(:locales).and_return(["en_US", "cz_CZ"])
      end

      it "returns the languages codes given by the fetcher" do
        expect(license.locales).to eq(["en_US", "cz_CZ"])
      end
    end

    context "when the fetcher is missing" do
      before do
        allow(license).to receive(:fetcher).and_return(nil)
      end

      it "returns a list containing the default language" do
        expect(license.locales).to eq([described_class::DEFAULT_LANG])
      end
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
