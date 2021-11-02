# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../test_helper"
require "y2packager/libzypp_backend"
require "y2packager/software_search"

Yast.import "Pkg"

describe Y2Packager::LibzyppBackend do
  subject(:backend) { described_class.new }

  describe "#probe" do
    it "initializes the packaging system" do
      # TODO: this is not the most useful test
      expect(Yast::Pkg).to receive(:SourceLoad)

      backend.probe
    end
  end

  describe "#repositories" do
    before do
      allow(Yast::Pkg).to receive(:SourceGetCurrent).with(false).and_return([0, 1])
      allow(Yast::Pkg).to receive(:SourceGeneralData).with(0)
        .and_return("name" => "SLES", "raw_url" => "file:///sles")
      allow(Yast::Pkg).to receive(:SourceGeneralData).with(1)
        .and_return("name" => "SLED", "raw_url" => "file:///sled")
    end

    it "returns the list of known repositories" do
      repos = backend.repositories
      expect(repos[0]).to be_a(Y2Packager::RpmRepo)
      expect(repos[0].name).to eq("SLES")
      expect(repos[1]).to be_a(Y2Packager::RpmRepo)
      expect(repos[1].name).to eq("SLED")
    end
  end

  describe "#search" do
    context "searching a package by name" do
      it "returns the package with the given name" do
        expect(Yast::Pkg).to receive(:Resolvables)
          .with({ kind: :package, name: "yast2" }, [:name, :version, :kind])
          .and_return([
                        { "name" => "yast2", "version" => "4.4.0", "source" => 1, "kind" => :package }
                      ])

        pkg = backend.search(
          conditions: { kind: :package, name: "yast2" }, properties: [:name, :version]
        ).first
        expect(pkg).to be_a(Y2Packager::Package)
        expect(pkg.name).to eq("yast2")
        expect(pkg.version).to eq("4.4.0")
        expect(pkg.repo_id).to eq(1)
      end
    end

    context "searching a product by name" do
      it "returns the product with the given name" do
        expect(Yast::Pkg).to receive(:Resolvables)
          .with(
            { kind: :product, name: "openSUSE" }, [:name, :version, :kind]
          )
          .and_return([
                        { "name" => "openSUSE", "version" => "20211027-0", "kind" => :product }
                      ])

        prod = backend.search(
          conditions: { kind: :product, name: "openSUSE" }, properties: [:name, :version]
        ).first
        expect(prod).to be_a(Y2Packager::Product)
        expect(prod.name).to eq("openSUSE")
        expect(prod.version).to eq("20211027-0")
      end
    end
  end
end
