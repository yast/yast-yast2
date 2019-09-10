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

require "y2packager/licenses_fetchers/tarball"
require "y2packager/package"

require "fileutils"

describe Y2Packager::LicensesFetchers::Tarball do
  subject(:fetcher) { described_class.new(product_name) }

  def tar_path_for(package)
    File.expand_path("../../../data/rpm/#{package}", __FILE__)
  end

  let(:lang) { "cz_CZ" }
  let(:product_name) { "SLES" }
  let(:tar_path) { tar_path_for("licenses_test.tar.gz") }

  before do
    allow(Yast::InstURL).to receive(:installInf2Url)
      .with("").and_return("file:///Foo")

    allow(Yast::Pkg).to receive(:RepositoryAdd)
      .and_return nil

    allow(Yast::Pkg).to receive(:SourceProvideFile)
      .and_return tar_path
  end

  it_behaves_like "a fetcher"

  describe "#content" do
    context "when a tar archive is found" do
      context "and there are license files available" do
        it "returns the requested license file content" do
          expect(fetcher.content(lang)).to match(/Dummy obsah/)
        end
      end

      context "and there is only the fallback license file available" do
        let(:tar_path) { tar_path_for("fallback_licenses_test.tar.gz") }

        it "returns the default license file content" do
          expect(fetcher.content(lang)).to match(/Dummy content for the fallback license file/)
        end
      end

      context "and there are none license files available" do
        let(:tar_path) { tar_path_for("dummy.tar.gz") }

        it "returns nil" do
          expect(fetcher.content(lang)).to be_nil
        end
      end
    end

    context "when a tar archive is not found" do
      let(:tar_path) { nil }

      it "returns nil" do
        expect(fetcher.content(lang)).to be_nil
      end
    end
  end

  describe "#locales" do
    context "when a tar archive is not found" do
      let(:tar_path) { nil }

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
      let(:tar_path) { tar_path_for("dummy.tar.gz") }

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
      let(:tar_path) { tar_path_for("dummy.tar.gz") }

      it "returns true" do
        expect(fetcher.confirmation_required?).to eq(true)
      end
    end
  end
end
