#!/usr/bin/env rspec
# typed: false
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

require_relative "../../test_helper"
require_relative "./shared_examples"

require "y2packager/licenses_fetchers/libzypp"

describe Y2Packager::LicensesFetchers::Libzypp do
  subject(:fetcher) { described_class.new(product_name) }

  let(:lang) { "en_US" }
  let(:product_name) { "SLES" }

  it_behaves_like "a fetcher"

  describe "#content" do
    before do
      allow(Yast::Pkg).to receive(:PrdGetLicenseToConfirm)
        .with(product_name, lang)
        .and_return(license_content)
    end

    context "when there is a license" do
      let(:license_content) { "Dummy license content" }

      it "returns the license content" do
        expect(fetcher.content(lang)).to eq("Dummy license content")
      end
    end

    context "when license not found" do
      let(:license_content) { nil }

      it "returns nil" do
        expect(fetcher.content(lang)).to be_nil
      end
    end
  end

  describe "#locales" do
    before do
      allow(Yast::Pkg).to receive(:PrdLicenseLocales).and_return(locales)
    end

    context "when license locales are found" do
      let(:locales) { ["en_US", "cz_CZ"] }

      it "returns list of available translations" do
        expect(fetcher.locales).to eq(["en_US", "cz_CZ"])
      end

      context "and there is an empty element in available translations" do
        let(:locales) { ["es_ES", "", "cz_CZ"] }

        it "replaces it by the default" do
          expect(fetcher.locales).to eq(["es_ES", described_class::DEFAULT_LANG, "cz_CZ"])
        end
      end
    end

    context "when locales are not found" do
      let(:locales) { nil }

      it "returns an empty list" do
        expect(fetcher.locales).to eq([])
      end
    end
  end
end
