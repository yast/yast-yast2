#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "PackagesProposal"

describe Yast::PackagesProposal do
  subject { Yast::PackagesProposal }

  let(:proposal_id) { "yast-proposal-test" }
  let(:packages) { ["grub2", "kexec-tools"] }

  let(:proposal_id2) { "yast-proposal-test2" }
  let(:packages2) { ["kdump"] }

  before do
    # store both required and optional resolvables
    subject.AddResolvables(proposal_id, :package, packages)
    subject.AddResolvables(proposal_id, :package, packages2, optional: true)
  end

  after do
    # make sure the internal state is reset after running the test
    subject.ResetAll
  end

  describe "ResetAll" do
    it "resets the added resolvables" do
      # not empty before, but empty after calling the reset
      expect { subject.ResetAll }.to change { subject.GetAllResolvablesForAllTypes }
        .from(package: packages).to({})
    end
  end

  describe "GetSupportedResolvables" do
    it "return the list of supported resolvables" do
      # ignore the order of the items
      expect(subject.GetSupportedResolvables).to match_array([:package, :pattern])
    end
  end

  describe "AddResolvables" do
    it "adds the required resolvables" do
      add_list = ["new_package"]
      subject.AddResolvables(proposal_id, :package, add_list)
      expect(subject.GetResolvables(proposal_id, :package)).to match_array(packages + add_list)
    end

    it "adds the optional resolvables" do
      add_list = ["new_package"]
      subject.AddResolvables(proposal_id, :package, add_list, optional: true)
      expect(subject.GetResolvables(proposal_id, :package, optional: true)).to \
        match_array(packages2 + add_list)
    end

    it "adding nil does not change the stored resolvables" do
      expect { subject.AddResolvables(proposal_id, :package, nil) }.to_not(
        change { subject.GetResolvables(proposal_id, :package) }
      )
    end
  end

  describe "GetResolvables" do
    it "returns the required resolvables" do
      ret = subject.GetResolvables(proposal_id, :package)
      expect(ret).to match_array(packages)
    end

    it "returns the optional resolvables" do
      ret = subject.GetResolvables(proposal_id, :package, optional: true)
      expect(ret).to match_array(packages2)
    end
  end

  describe "SetResolvables" do
    it "removes the previous resolvables and sets new ones" do
      expect { subject.SetResolvables(proposal_id, :package, packages2) }.to(
        change { subject.GetResolvables(proposal_id, :package) }
        .from(packages).to(packages2)
      )
    end

    it "removes the previous optional resolvables and sets new ones" do
      expect { subject.SetResolvables(proposal_id, :package, packages, optional: true) }.to(
        change { subject.GetResolvables(proposal_id, :package, optional: true) }
        .from(packages2).to(packages)
      )
    end

    it "resets to empty list when nil is used" do
      expect { subject.SetResolvables(proposal_id, :package, nil) }.to(
        change { subject.GetResolvables(proposal_id, :package) }
        .from(packages).to([])
      )
    end
  end

  describe "RemoveResolvables" do
    it "removes only the listed resolvables" do
      expect { subject.RemoveResolvables(proposal_id, :package, ["kexec-tools"]) }.to(
        change { subject.GetResolvables(proposal_id, :package) }
        .from(["grub2", "kexec-tools"]).to(["grub2"])
      )
    end

    it "keeps the optional resolvables when removing the required ones" do
      expect { subject.RemoveResolvables(proposal_id, :package, ["kexec-tools"]) }.to_not(
        change { subject.GetResolvables(proposal_id, :package, optional: true) }
      )
    end

    it "removes only the listed optional resolvables" do
      expect { subject.RemoveResolvables(proposal_id, :package, ["kdump"], optional: true) }.to(
        change { subject.GetResolvables(proposal_id, :package, optional: true) }
        .from(["kdump"]).to([])
      )
    end

    it "keeps the optional resolvables when removing the required ones" do
      expect { subject.RemoveResolvables(proposal_id, :package, packages2, optional: true) }.to_not(
        change { subject.GetResolvables(proposal_id, :package) }
      )
    end

    it "does not remove anything when nil is used" do
      expect { subject.RemoveResolvables(proposal_id, :package, nil) }.to_not(
        change { subject.GetResolvables(proposal_id, :package) }
      )
    end
  end

  describe "GetResolvables" do
    it "returns the required resolvables" do
      expect(subject.GetResolvables(proposal_id, :package)).to match_array(packages)
    end

    it "returns the optional resolvables" do
      expect(subject.GetResolvables(proposal_id, :package, optional: true)).to \
        match_array(packages2)
    end

    it "returns nil for invalid ID" do
      expect(subject.GetResolvables(nil, :package)).to be_nil
      expect(subject.GetResolvables(nil, :package, optional: true)).to be_nil
    end

    it "returns nil for invalid resolvable type" do
      expect(subject.GetResolvables(proposal_id, :foobar)).to be_nil
      expect(subject.GetResolvables(proposal_id, :foobar, optional: true)).to be_nil
    end

    it "returns nil for nil resolvable type" do
      expect(subject.GetResolvables(proposal_id, nil)).to be_nil
      expect(subject.GetResolvables(proposal_id, nil, optional: true)).to be_nil
    end
  end

  describe "GetAllResolvables" do
    it "returns nil if unsupported resolvable type is used" do
      expect(subject.GetAllResolvables(:foobar)).to be_nil
    end

    it "returns nil if unsupported resolvable type is used for optional resolvables" do
      expect(subject.GetAllResolvables(:foobar, optional: true)).to be_nil
    end

    it "returns the required resolvables" do
      expect(subject.GetAllResolvables(:package)).to eq(packages)
    end

    it "returns the optional resolvables" do
      expect(subject.GetAllResolvables(:package, optional: true)).to eq(packages2)
    end
  end

  describe "GetAllResolvablesForAllTypes" do
    it "returns the required resolvables" do
      expect(subject.GetAllResolvablesForAllTypes).to eq(package: packages)
    end

    it "returns the optional resolvables" do
      expect(subject.GetAllResolvablesForAllTypes(optional: true)).to \
        eq(package: packages2)
    end
  end

  describe "IsUniqueID" do
    it "returns nil for nil" do
      expect(subject.IsUniqueID(nil)).to be_nil
    end

    it "returns nil for empty string" do
      expect(subject.IsUniqueID("")).to be_nil
    end

    it "returns true if the ID is not already used" do
      expect(subject.IsUniqueID("no-existing-proposal-id")).to eq(true)
    end

    it "returns false if the ID is already used" do
      expect(subject.IsUniqueID(proposal_id)).to eq(false)
    end
  end
end
