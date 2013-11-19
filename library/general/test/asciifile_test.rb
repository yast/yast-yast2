#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
include Yast

Yast.import "AsciiFile"

FSTAB_FILENAME = "/etc/fstab"
FSTAB_CONTENTS = <<EOS
UUID=001c0d61-e99f-4ab7-ba4b-bda6f54a052d       /       btrfs   defaults 0 0
# NFS
192.168.1.1:/ /mnt    nfs4    rw 0 0
# trailing comment
EOS

def stub_fstab(filename = FSTAB_FILENAME, contents = FSTAB_CONTENTS)
  SCR.stub(:Read)
    .with(path(".target.size"), filename)
    .and_return contents.length

  SCR.stub(:Read)
    .with(path(".target.string"), filename)
    .and_return contents
end

describe "AsciiFile" do
  describe "#ReadFile" do
    it "does something" do
      stub_fstab "/etc/fstab"
      fstab = {}
      fstab_ref = arg_ref(fstab)
      AsciiFile.SetComment(fstab_ref, "^[ \t]*#")
      AsciiFile.SetDelimiter(fstab_ref, " \t")
      AsciiFile.SetListWidth(fstab_ref, [20, 20, 10, 21, 1, 1])
      AsciiFile.ReadFile(fstab_ref, "/etc/fstab")

      expect(fstab["l"].size).to eq 4

      # l: (lines) are a hash indexed by integers starting at ONE!
      expect(fstab["l"][1]["fields"].size).to eq 6
      # fields: an array starting at zero as usual
      expect(fstab["l"][1]["fields"][1]).to eq "/"

      expect(fstab["l"][2]["comment"]).to be_true
      expect(fstab["l"][2]["line"]).to eq "# NFS"
    end
  end
end
