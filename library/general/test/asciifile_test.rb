#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "AsciiFile"

def stub_file_reading(filename, contents)
  allow(Yast::SCR).to receive(:Read)
    .with(path(".target.size"), filename)
    .and_return contents.length

  allow(Yast::SCR).to receive(:Read)
    .with(path(".target.string"), filename)
    .and_return contents
end

describe "AsciiFile" do
  context "when working with a fstab file" do
    FSTAB_FILENAME = "/etc/fstab".freeze
    FSTAB_CONTENTS = <<EOS.freeze
UUID=001c0d61-e99f-4ab7-ba4b-bda6f54a052d       /       btrfs   defaults 0 0
# NFS
192.168.1.1:/ /mnt    nfs4    rw 0 0
# trailing comment
EOS
    let(:fstab_ref) do
      stub_file_reading(FSTAB_FILENAME, FSTAB_CONTENTS)
      fstab = {}
      fstab_ref = Yast::ArgRef.new(fstab)
      Yast::AsciiFile.SetComment(fstab_ref, "^[ \t]*#")
      Yast::AsciiFile.SetDelimiter(fstab_ref, " \t")
      Yast::AsciiFile.SetListWidth(fstab_ref, [20, 20, 10, 21, 1, 1])
      fstab_ref
    end

    describe "#ReadFile" do
      before(:each) do
        Yast::AsciiFile.ReadFile(fstab_ref, FSTAB_FILENAME)
      end

      # note that the result is `fstab["l"]`
      # as the rest of `fstab` are the parsing parameters
      it "produces the result under the 'l' key" do
        expect(fstab_ref.value).to have_key "l"
      end

      describe "the result" do
        subject(:result) { fstab_ref.value["l"] }

        it "is a hash indexed by line numbers, starting at ONE" do
          expect(result.keys).to eq [1, 2, 3, 4]
        end

        describe "comment lines" do
          subject(:comment) { result[2] }

          it "have a true 'comment' key" do
            expect(comment["comment"]).to eq(true)
          end

          it "have a copy in 'line' key, including the comment start" do
            expect(comment["line"]).to eq "# NFS"
          end
        end

        describe "regular non-comment lines" do
          subject(:regular) { result[1] }

          it "have a falsy 'comment' key" do
            expect(!regular["comment"]).to eq(true)
          end

          it "have a copy in 'line' key" do
            expect(regular["line"]).to eq "UUID=001c0d61-e99f-4ab7-ba4b-bda6f54a052d       /       btrfs   defaults 0 0"
          end

          describe "its 'fields' key" do
            it "is an array of delimiter separated fields, starting at zero as usual" do
              expect(regular["fields"].size).to eq 6
              expect(regular["fields"][1]).to eq "/"
            end
          end
        end
      end
    end
  end
end
