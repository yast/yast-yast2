#! /usr/bin/env rspec

require_relative "test_helper"

Yast.import "Installation"

describe Yast::Installation do
  subject { Yast::Installation }

  describe ".sourcedir" do
    before do
      allow(::File).to receive(:exist?).and_return(true)
    end

    it "returns string" do
      expect(subject.sourcedir).to eq "/run/YaST2/mount"
    end

    it "ensures that directory exists" do
      expect(::File).to receive(:exist?).and_return(false)
      expect(::FileUtils).to receive(:mkdir_p)

      subject.sourcedir
    end
  end

  # test the module constructor
  describe "#Installation (module constructor)" do
    before do
      # mock a running system
      allow(Yast::Stage).to receive(:cont).and_return(false)
      allow(Yast::Stage).to receive(:initial).and_return(false)
    end

    before(:each) do
      # reset the value before each run
      subject.destdir = "/"
    end

    context "YAST_TARGET_DIR is not set" do
      before do
        expect(ENV).to receive(:[]).with("YAST_TARGET_DIR").and_return(nil)
      end

      it "sets the 'destdir' to /" do
        subject.Installation
        expect(subject.destdir).to eq("/")
      end
    end

    context "YAST_TARGET_DIR is set" do
      let(:target_dir) { "/mnt" }
      before do
        expect(ENV).to receive(:[]).with("YAST_TARGET_DIR").and_return(target_dir)
      end

      context "the target directory exists" do
        before do
          expect(File).to receive(:directory?).with(target_dir).and_return(true)
        end

        it "sets the 'destdir' to the target directory" do
          subject.Installation
          expect(subject.destdir).to eq(target_dir)
        end
      end

      context "the target directory does not exist" do
        before do
          expect(File).to receive(:directory?).with(target_dir).and_return(false)
        end

        it "aborts with an error" do
          expect(subject).to receive(:abort)
          subject.Installation
        end
      end
    end
  end
end
