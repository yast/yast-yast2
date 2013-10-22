#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
include Yast

Yast.import "Linuxrc"

DEFAULT_INSTALL_INF = {
  "Manual" => "0",
  "Locale" => "xy_XY",
  "Display" => "Color",
  "HasPCMCIA" => "0",
  "NoPCMCIA" => "0",
  "Sourcemounted" => "1",
  "SourceType" => "dir",
  "RepoURL" => "cd:/?device=disk/by-id/ata-VBOX_CD-ROM_VB2-01700376",
  "InstsysURL" => "boot/x86_64/root",
  "ZyppRepoURL" => "cd:/?devices=/dev/disk/by-id/ata-VBOX_CD-ROM_VB2-01700376",
  "InstMode" => "cd",
  "Device" => "disk/by-id/ata-VBOX_CD-ROM_VB2-01700376",
  "Cdrom" => "disk/by-id/ata-VBOX_CD-ROM_VB2-01700376",
  "Partition" => "disk/by-id/ata-VBOX_CD-ROM_VB2-01700376",
  "Serverdir" => "/",
  "InitrdModules" => "ata_piix ata_generic cdrom sr_mod st sg thermal_sys thermal",
  "Options" => "thermal tzp=50",
  "UpdateDir" => "/linux/suse/x86_64-13.1",
  "YaST2update" => "0",
  "Textmode" => "0",
  "MemFree" => "989888",
  "VNC" => "0",
  "UseSSH" => "0",
  "InitrdID" => "2013-09-17.8c48b884",
  "WithiSCSI" => "0",
  "WithFCoE" => "0",
  "StartShell" => "0",
  "Y2GDB" => "0",
  "kexec_reboot" => "1",
  "UseSax2" => "0",
  "EFI" => "0",
  "Ignored_featureS" => "import_ssh_keys,import_users",
  "Cmdline" => "splash=silent vga=0x314",
  "Keyboard" => "1",
  "Framebuffer" => "0x0314",
  "X11i" => "",
  "XServer" => "fbdev",
  "XVersion" => "4",
  "XBusID" => "0:2:0",
  "XkbRules" => "xfree86",
  "XkbModel" => "pc104",
  "umount_result" => "0",
}

def load_install_inf(defaults_replacement={})
  # Default value
  SCR.stub(:Read).and_return nil

  SCR.stub(:Read)
    .with(path(".target.size"))
    .and_return 1

  # Default value
  SCR.stub(:Dir).and_return nil

  install_inf = DEFAULT_INSTALL_INF.merge(defaults_replacement)

  SCR.stub(:Dir)
    .with(path(".etc.install_inf"))
    .and_return install_inf.keys

  install_inf.keys.each do |key|
    Yast::SCR.stub(:Read)
      .with(path(".etc.install_inf.#{key}"))
      .and_return install_inf[key]
  end
end

describe "Linuxrc" do

  before(:each) do
    Linuxrc.ResetInstallInf
  end

  describe "#serial_console" do
    it "returns true if 'Console' is found in install.inf" do
      load_install_inf("Console" => "/dev/console")
      expect(Linuxrc.serial_console).to be_true
    end

    it "returns false if 'Console' is not found in install.inf" do
      load_install_inf("Console" => nil)
      expect(Linuxrc.serial_console).to be_false
    end
  end

  describe "#braille" do
    it "returns true if 'Braille' is found in install.inf" do
      load_install_inf("Braille" => "/dev/braille")
      expect(Linuxrc.braille).to be_true
    end

    it "returns false if 'Braille' is not found in install.inf" do
      load_install_inf("Braille" => nil)
      expect(Linuxrc.braille).to be_false
    end
  end

  describe "#vnc" do
    it "returns true if 'VNC' is set to '1' in install.inf" do
      load_install_inf("VNC" => "1")
      expect(Linuxrc.vnc).to be_true
    end

    it "returns false if 'VNC' is not set to '1' in install.inf" do
      load_install_inf("VNC" => "0")
      expect(Linuxrc.vnc).to be_false
    end
  end

  describe "#display_ip" do
    it "returns true if 'Display_IP' is found in install.inf" do
      load_install_inf("Display_IP" => "1.2.3.4")
      expect(Linuxrc.display_ip).to be_true
    end

    it "returns false if 'Display_IP' is not found in install.inf" do
      load_install_inf("Display_IP" => nil)
      expect(Linuxrc.display_ip).to be_false
    end
  end

  describe "#usessh" do
    it "returns true if 'UseSSH' is set to '1' in install.inf" do
      load_install_inf("UseSSH" => "1")
      expect(Linuxrc.usessh).to be_true
    end

    it "returns false if 'UseSSH' is not set to '1' in install.inf" do
      load_install_inf("UseSSH" => "0")
      expect(Linuxrc.usessh).to be_false
    end
  end

  describe "#useiscsi" do
    it "returns true if 'WithiSCSI' is set to '1' in install.inf" do
      load_install_inf("WithiSCSI" => "1")
      expect(Linuxrc.useiscsi).to be_true
    end

    it "returns false if 'WithiSCSI' is not set to '1' in install.inf" do
      load_install_inf("WithiSCSI" => "0")
      expect(Linuxrc.useiscsi).to be_false
    end
  end

  describe "#text" do
    it "returns true if 'Textmode' is set to '1' in install.inf" do
      load_install_inf("Textmode" => "1")
      expect(Linuxrc.text).to be_true
    end

    it "returns false if 'Textmode' is not set to '1' in install.inf" do
      load_install_inf("Textmode" => "0")
      expect(Linuxrc.text).to be_false
    end
  end

  describe "#InstallInf" do
    it "returns locale defined in install.inf" do
      load_install_inf
      expect(Linuxrc.InstallInf("Locale")).to be_equal(DEFAULT_INSTALL_INF["Locale"])
    end

    it "returns nil if value for unknown key is requested" do
      load_install_inf
      expect(Linuxrc.InstallInf("Unknown Key Requested")).to be_nil
    end

    it "returns nil if value for 'nil' key is requested" do
      load_install_inf
      expect(Linuxrc.InstallInf(nil)).to be_nil
    end
  end

  describe "#keys" do
    it "returns all keys defined in install.inf" do
      load_install_inf
      expect(Linuxrc.keys.sort).to eq(DEFAULT_INSTALL_INF.keys.sort)
    end
  end
end
