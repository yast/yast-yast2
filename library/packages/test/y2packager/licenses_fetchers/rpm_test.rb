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

require_relative "../../test_helper"
require_relative "./shared_examples"

require "y2packager/licenses_fetchers/rpm"
require "y2packager/package"

describe Y2Packager::LicensesFetchers::Rpm do
  subject(:fetcher) { described_class.new(product_name) }

  let(:lang) { "en_US" }
  let(:product_name) { "SLES" }
  let(:package_name) { "sles-release" }
  let(:package_properties) { [{ "product_package" => package_name }] }
  let(:package_status) { :selected }
  let(:package) { instance_double(Y2Packager::Package, status: package_status, extract_to: nil) }

  before do
    allow(Yast::Pkg).to receive(:ResolvableProperties)
      .with(product_name, :product, "")
      .and_return(package_properties)

    allow(Y2Packager::Package).to receive(:find)
      .with(package_name)
      .and_return([package])
  end

  it_behaves_like "a fetcher"

  describe "#content" do
    context "when a selected package is found" do
      let(:license_path) { "/fake/path/to/#{lang}/LICENSE" }
      let(:default_license_path) { "/fake/path/to/default/txt/license" }
      let(:license_file_content) { "" }

      before do
        allow(Dir).to receive(:glob).and_call_original
        allow(Dir).to receive(:glob).with(/#{lang}/, anything).and_return([license_path])
        allow(Dir).to receive(:glob).with(/LICENSE.TXT/, anything).and_return([default_license_path])
        allow(File).to receive(:read).with(license_path).and_return(license_file_content)
        allow(File).to receive(:read).with(default_license_path).and_return(license_file_content)
      end

      context "and there are license files available" do
        let(:license_file_content) { "Dummy content license for #{lang} language" }

        it "returns the license file content" do
          expect(fetcher.content(lang)).to match(/license for #{lang} language/)
        end
      end

      context "and there is only the fallback license file available" do
        let(:license_path) { nil }
        let(:license_file_content) { "Dummy default license content" }

        it "returns the default license file content" do
          expect(fetcher.content(lang)).to eq("Dummy default license content")
        end
      end

      context "and there are none license files available" do
        let(:license_path) { nil }
        let(:default_license_path) { nil }

        it "returns nil" do
          expect(fetcher.content(lang)).to be_nil
        end
      end
    end

    context "when package name is not found" do
      let(:package_properties) { {} }

      it "returns nil" do
        expect(fetcher.content(lang)).to be_nil
      end
    end

    context "when package is not selected" do
      let(:package_status) { :unknown }

      it "returns nil" do
        expect(fetcher.content(lang)).to be_nil
      end
    end
  end

  describe "#locales" do
    before do
      allow(Dir).to receive(:glob).and_call_original
      allow(Dir).to receive(:glob)
        .with(/LICENSE.*.TXT/, anything)
        .and_return(available_license_files)
    end

    context "when package is not found" do
      let(:package) { nil }
      let(:available_license_files) { [] }

      it "returns an empty list" do
        expect(fetcher.locales).to eq([])
      end
    end

    context "when license translation files are not found" do
      let(:available_license_files) { ["/fake/path/to/LICENSE.TXT"] }

      it "returns a list with the default language" do
        expect(fetcher.locales).to eq([described_class::DEFAULT_LANG])
      end
    end

    context "when license translation files are found" do
      let(:available_license_files) do
        [
          "/fake/path/to/LICENSE.cz_CZ.TXT",
          "/fake/path/to/LICENSE.es_ES.TXT",
          "/fake/path/to/LICENSE.TXT"
        ]
      end

      it "returns a list with available locales and the default lang" do
        expect(fetcher.locales).to eq(["cz_CZ", "es_ES", described_class::DEFAULT_LANG])
      end
    end
  end
end
