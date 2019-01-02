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

require "y2packager/package"
require "y2packager/licenses_handlers/rpm"

describe Y2Packager::LicensesHandlers::Rpm do
  subject(:handler) { described_class.new(product_name) }

  let(:product_name) { "SLES" }
  let(:package) { instance_double(Y2Packager::Package, extract_to: nil) }

  describe "#confirmation_required?" do
    before do
      allow(Dir).to receive(:mktmpdir)
      allow(Dir).to receive(:glob).and_return(found_paths)
      allow(File).to receive(:join)
      allow(FileUtils).to receive(:remove_entry_secure)
      allow(subject).to receive(:package).and_return(package)
    end

    context "when 'no-acceptance-neeed' file is present" do
      let(:found_paths) { ["/fake/no-acceptance-file-path"] }

      it "returns false" do
        expect(handler.confirmation_required?).to eq(false)
      end
    end

    context "when 'no-acceptance-neeed' file is not found" do
      let(:found_paths) { [] }

      it "returns true" do
        expect(handler.confirmation_required?).to eq(true)
      end
    end
  end
end
