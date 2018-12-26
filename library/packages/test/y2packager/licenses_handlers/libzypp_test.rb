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

require "y2packager/licenses_handlers/libzypp"

describe Y2Packager::LicensesHandlers::Libzypp do
  subject(:handler) { described_class.new(product_name) }

  let(:product_name) { "SLES" }

  describe "#license_confirmation_required?" do
    before do
      allow(Yast::Pkg).to receive(:PrdNeedToAcceptLicense)
        .with(product_name).and_return(needed)
    end

    context "when according to libzypp the license is required to be confirmed" do
      let(:needed) { true }

      it "returns true" do
        expect(handler.confirmation_required?).to eq(true)
      end
    end

    context "when according to libzypp the license is not required to be confirmed" do
      let(:needed) { false }

      it "returns false" do
        expect(handler.confirmation_required?).to eq(false)
      end
    end
  end
end
