#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
include Yast

Yast.import "AsciiFile"

def stub_file_reading(filename, contents)
  SCR.stub(:Read)
    .with(path(".target.size"), filename)
    .and_return contents.length

  SCR.stub(:Read)
    .with(path(".target.string"), filename)
    .and_return contents
end

describe "AsciiFile" do
  context "when working with a fstab file" do
    FSTAB_FILENAME = "/etc/fstab"
    FSTAB_CONTENTS = <<EOS
UUID=001c0d61-e99f-4ab7-ba4b-bda6f54a052d       /       btrfs   defaults 0 0
# NFS
192.168.1.1:/ /mnt    nfs4    rw 0 0
# trailing comment
EOS
    let(:fstab_ref) do
      stub_file_reading(FSTAB_FILENAME, FSTAB_CONTENTS)
      fstab = {}
      fstab_ref = arg_ref(fstab)
      AsciiFile.SetComment(fstab_ref, "^[ \t]*#")
      AsciiFile.SetDelimiter(fstab_ref, " \t")
      AsciiFile.SetListWidth(fstab_ref, [20, 20, 10, 21, 1, 1])
      fstab_ref
    end

    describe "#ReadFile" do
      before(:each) do
        AsciiFile.ReadFile(fstab_ref, FSTAB_FILENAME)
      end

      # note that the result is `fstab["l"]`
      # as the rest of `fstab` are the parsing parameters
      subject(:result) { fstab_ref.value["l"] }

      it "counts the lines" do
        expect(result.size).to eq 4
      end
      it "indexes the lines, starting at ONE" do
        expect(result.keys).to eq [1, 2, 3, 4]
      end
      it "counts the fields" do
        expect(result[1]["fields"].size).to eq 6
      end
      it "indexes the fields, starting at zero as usual" do
        expect(result[1]["fields"][1]).to eq "/"
      end
      it "recognizes comments" do
        expect(result[2]["comment"]).to be_true
      end
      it "preserves the comment start" do
        expect(result[2]["line"]).to eq "# NFS"
      end
    end
  end
end
