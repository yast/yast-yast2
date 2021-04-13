# Copyright (c) [2019] SUSE LLC
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

require_relative "test_helper"

Yast.import "ShadowConfig"

describe Yast::ShadowConfig do
  subject { Yast::ShadowConfig }

  let(:login_defs) { CFA::LoginDefs.new }

  before do
    allow(CFA::LoginDefs).to receive(:new)
      .and_return(login_defs)
    subject.reset
    subject.main
  end

  describe "#fetch" do
    before do
      allow(login_defs).to receive(:encrypt_method).and_return("SHA512")
    end

    context "when the value is defined" do
      it "returns the value for the given attribute" do
        expect(subject.fetch(:encrypt_method)).to eq("SHA512")
      end
    end

    context "when the value is unknown" do
      it "raises an exception" do
        expect { subject.fetch(:unknown) }
          .to raise_error(Yast::ShadowConfigClass::UnknownAttributeError)
      end
    end
  end

  describe "#set" do
    context "when the value is defined" do
      it "sets the attribute to the given value" do
        expect { subject.set(:encrypt_method, "SHA256") }
          .to change { subject.fetch(:encrypt_method) }
          .to("SHA256")
      end
    end

    context "when the value is unknown" do
      it "raises an exception" do
        expect { subject.set(:unknown, "unknown") }
          .to raise_error(Yast::ShadowConfigClass::UnknownAttributeError)
      end
    end
  end

  describe "#write" do
    it "saves the changes" do
      expect(login_defs).to receive(:save)
      subject.write
    end
  end
end
