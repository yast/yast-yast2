#!/usr/bin/env rspec

require_relative "test_helper"
require "yast2/execute"

Yast.import "Report"

describe Yast::Execute do
  it "sets yast logger as cheetah logger" do
    expect(Cheetah.default_options[:logger]).to eq Yast::Y2Logger.instance
  end

  describe ".locally" do
    it "passes arguments directly to cheetah" do
      expect(Cheetah).to receive(:run).with("ls", "-a")

      Yast::Execute.locally("ls", "-a")
    end

    it "report error if command execution failed" do
      expect(Yast::Report).to receive(:Error)
      Yast::Execute.locally("false")
    end

    it "returns nil if command execution failed" do
      expect(Yast::Execute.locally("false")).to eq nil
    end
  end

  describe ".locally!" do
    it "passes arguments directly to cheetah" do
      expect(Cheetah).to receive(:run).with("ls", "-a")

      Yast::Execute.locally("ls", "-a")
    end

    it "raises Cheetah::ExecutionFailed if command execution failed" do
      expect { Yast::Execute.locally!("false") }.to raise_error(Cheetah::ExecutionFailed)
    end
  end

  describe ".on_target" do
    it "adds to passed arguments chroot option if scr chrooted" do
      allow(Yast::WFM).to receive(:scr_root).and_return("/mnt")
      expect(Cheetah).to receive(:run).with("ls", "-a", chroot: "/mnt")

      Yast::Execute.on_target("ls", "-a")
    end

    it "report error if command execution failed" do
      expect(Yast::Report).to receive(:Error)
      Yast::Execute.on_target("false")
    end

    it "returns nil if command execution failed" do
      expect(Yast::Execute.on_target("false")).to eq nil
    end
  end

  describe ".on_target!" do
    it "adds to passed arguments chroot option if scr chrooted" do
      allow(Yast::WFM).to receive(:scr_root).and_return("/mnt")
      expect(Cheetah).to receive(:run).with("ls", "-a", chroot: "/mnt")

      Yast::Execute.on_target("ls", "-a")
    end

    it "raises Cheetah::ExecutionFailed if command execution failed" do
      expect { Yast::Execute.on_target!("false") }.to raise_error(Cheetah::ExecutionFailed)
    end
  end
end
