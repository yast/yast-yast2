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

require "y2packager/licenses_fetchers/rpm"
require "y2packager/package"

require "fileutils"

describe Y2Packager::LicensesFetchers::Rpm do
  subject(:fetcher) { described_class.new(product_name) }

  def rpm_path_for(package)
    File.expand_path("../../../data/rpm/#{package}", __FILE__)
  end

  let(:lang) { "cz_CZ" }
  let(:product_name) { "SLES" }
  let(:package_name) { "sles-release" }
  let(:package_properties) do
    [Y2Packager::Resolvable.new(kind: :product,
    name: "SLE_RT", status: :available, source: 2, product_package: package_name)]
  end
  let(:package_status) { :selected }
  let(:package_path) { rpm_path_for("licenses_test_package-0.1-0.noarch.rpm") }
  let(:package) do
    double = instance_double(Y2Packager::Package, status: package_status)
    allow(double).to receive(:extract_to) do |dir|
      Packages::PackageExtractor.new(package_path).extract(dir)
    end
    double
  end
  let(:found_packages) { [package] }

  before do
    allow(Y2Packager::Resolvable).to receive(:find)
      .with(kind: :product, name: product_name)
      .and_return(package_properties)

    allow(Y2Packager::Package).to receive(:find)
      .with(package_name)
      .and_return(found_packages)
  end

  it_behaves_like "a fetcher"

  describe "#content" do
    context "when a selected package is found" do
      context "and there are license files available" do
        it "returns the requested license file content" do
          expect(fetcher.content(lang)).to match(/Dummy obsah/)
        end
      end

      context "and there is only the fallback license file available" do
        let(:package_path) { rpm_path_for("fallback_licenses_test_package-0.1-0.noarch.rpm") }

        it "returns the default license file content" do
          expect(fetcher.content(lang)).to match(/Dummy content for the fallback license file/)
        end
      end

      context "and there are none license files available" do
        let(:package_path) { rpm_path_for("dummy_package-0.1-0.noarch.rpm") }

        it "returns nil" do
          expect(fetcher.content(lang)).to be_nil
        end
      end
    end

    context "when package name is not found" do
      let(:package_properties) { [] }

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
    context "when package is not found" do
      let(:found_packages) { nil }

      it "returns an empty list" do
        expect(fetcher.locales).to eq([])
      end
    end

    context "when license translation files are found" do
      it "returns a list with available locales" do
        expect(fetcher.locales).to match_array(["cz_CZ", "en_US", "es_ES"])
      end
    end

    context "when license translation files are not found" do
      let(:package_path) { rpm_path_for("dummy_package-0.1-0.noarch.rpm") }

      it "returns a list with the default language" do
        expect(fetcher.locales).to eq([described_class::DEFAULT_LANG])
      end
    end
  end

  describe "#confirmation_required?" do
    context "when 'no-acceptance-neeed' file is present" do
      it "returns false" do
        expect(fetcher.confirmation_required?).to eq(false)
      end
    end

    context "when 'no-acceptance-neeed' file is not found" do
      let(:package_path) { rpm_path_for("dummy_package-0.1-0.noarch.rpm") }

      it "returns true" do
        expect(fetcher.confirmation_required?).to eq(true)
      end
    end
  end
end
