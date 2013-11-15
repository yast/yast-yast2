# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2002 - 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# ***************************************************************************
module Yast

  #inject NetworkInterfaces accessor so we can modify Devices
  class NetworkInterfacesClass < Module
    attr_accessor :Devices
    attr_accessor :OriginalDevices
  end

  class NetworkInterfaces2Client < Client
    def main
      Yast.include self, "testsuite.rb"

      @READ = {
        "network" => {
          "section" => {
            "arc5"      => nil,
            "atm5"      => nil,
            "ci5"       => nil,
            "ctc5"      => nil,
            "dummy5"    => nil,
            "escon5"    => nil,
            "eth5"      => nil,
            "eth6"      => nil,
            "eth7"      => nil,
            "eth8"      => nil,
            "eth9"      => nil,
            #	    "eth-pcmcia": nil,
            #	    "eth-usb"	: nil,
            "mynet0"    => nil,
            "fddi5"     => nil,
            "hippi5"    => nil,
            "hsi5"      => nil,
            "ippp5"     => nil,
            "iucv5"     => nil,
            "lo"        => nil,
            "myri5"     => nil,
            "ppp5"      => nil,
            "tr5"       => nil,
            "tr~"       => nil,
            "vlan3"     => nil,
            "eth0.3"    => nil,
            "virtlan4"  => nil,
            "myvlantoo" => nil
          },
          "value"   => {
            "arc5"      => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            "atm5"      => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            "ci5"       => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            "ctc5"      => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            "dummy5"    => {
              "BOOTPROTO" => "static",
              "IPADDR"    => "1.2.3.4",
              "NETMASK"   => "255.0.0.0",
              "STARTMODE" => "manual"
            },
            "escon5"    => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            "eth5" =>
              # "IPADDR_x":"1.1.1.1", "NETMASK_x":"0.0.0.0"
              { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            # 32 bit prefix
            "eth6"      => {
              "BOOTPROTO" => "static",
              "IPADDR"    => "1.2.3.4",
              "STARTMODE" => "manual"
            },
            "eth7"      => { "STARTMODE" => "manual" },
            "eth8"      => { "IPADDR" => "1.2.3.4/8", "STARTMODE" => "manual" },
            "eth9"      => {
              "IPADDR"    => "1.2.3.4",
              "PREFIXLEN" => "8",
              "STARTMODE" => "manual"
            },
            #	    "eth-pcmcia": $["BOOTPROTO":"dhcp", "STARTMODE":"hotplug"],
            #	    "eth-usb"	: $["BOOTPROTO":"dhcp", "STARTMODE":"hotplug"],
            "mynet0"    => {
              "BOOTPROTO"     => "dhcp",
              "STARTMODE"     => "auto",
              "INTERFACETYPE" => "eth"
            },
            "fddi5"     => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            "hippi5"    => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            "hsi5"      => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            "ippp5"     => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            "iucv5"     => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            "lo" =>
              # "IPADDR_1":"7.7.7.7"
              {
                "BROADCAST" => "127.255.255.255",
                "IPADDR"    => "127.0.0.1",
                "NETMASK"   => "255.0.0.0",
                "NETWORK"   => "127.0.0.0",
                "STARTMODE" => "onboot"
              },
            "myri5"     => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            "ppp5"      => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            "tr5"       => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
            "vlan3"     => {
              "BOOTPROTO"   => "dhcp",
              "STARTMODE"   => "manual",
              "ETHERDEVICE" => "eth0"
            },
            "eth0.3"    => {
              "BOOTPROTO"   => "dhcp",
              "STARTMODE"   => "manual",
              "ETHERDEVICE" => "eth0"
            },
            "virtlan4"  => {
              "BOOTPROTO"   => "dhcp",
              "STARTMODE"   => "manual",
              "ETHERDEVICE" => "eth0"
            },
            "myvlantoo" => {
              "BOOTPROTO"   => "dhcp",
              "STARTMODE"   => "manual",
              "ETHERDEVICE" => "eth0",
              "VLAN_ID"     => "2"
            }
          }
        },
        "probe"   => { "system" => [] },
        "target"  => { "tmpdir" => "/tmp" }
      }

      @EXEC = {
        "target" => {
          "bash_output" => { "exit" => 0, "stdout" => "", "stderr" => "" }
        }
      }

      TESTSUITE_INIT([@READ, {}, @EXEC], nil)
      Yast.import "NetworkInterfaces"

      DUMP("NetworkInterfaces::Read")
      TEST(lambda { NetworkInterfaces.Read }, [@READ, {}, @EXEC], nil)
      DUMP(Builtins.sformat("all=%1", NetworkInterfaces.Devices))
      NetworkInterfaces.OriginalDevices = nil

      DUMP("NetworkInterfaces::Write")
      TEST(lambda { NetworkInterfaces.Write("eth") }, [@READ], nil)
      TEST(lambda { NetworkInterfaces.Write("ppp") }, [@READ], nil)
      TEST(lambda { NetworkInterfaces.Write("ippp") }, [@READ], nil)
      TEST(lambda { NetworkInterfaces.Write("trx") }, [@READ], nil)
      TEST(lambda { NetworkInterfaces.Write("atm|tr") }, [@READ], nil)
      TEST(lambda { NetworkInterfaces.Write("") }, [@READ], nil)

      @exported = nil

      DUMP("NetworkInterfaces::Export")
      @exported = NetworkInterfaces.Export("")
      DUMP(Builtins.sformat("exported=%1", @exported))

      # Test import canonicalizing
      DUMP("NetworkInterfaces::Import")
      Ops.set(@exported, ["lo", "lo", "STARTMODE"], "boot")
      Ops.set(@exported, ["eth", "eth6", "IPADDR"], "1.2.3.4/8")
      NetworkInterfaces.Import("", @exported)
      DUMP(Builtins.sformat("all     =%1", NetworkInterfaces.Devices))

      DUMP("NetworkInterfaces::GetFreeDevices")
      NetworkInterfaces.Devices = { "eth" => { "0" => {} } }
      TEST(lambda { NetworkInterfaces.GetFreeDevices("eth", 2) }, [], nil)
      NetworkInterfaces.Devices = { "eth" => { "1" => {} } }
      TEST(lambda { NetworkInterfaces.GetFreeDevices("eth", 2) }, [], nil)
      NetworkInterfaces.Devices = { "eth" => { "2" => {} } }
      TEST(lambda { NetworkInterfaces.GetFreeDevices("eth", 2) }, [], nil)
      NetworkInterfaces.Devices = { "eth-pcmcia" => { "" => {} } }
      TEST(lambda { NetworkInterfaces.GetFreeDevices("eth-pcmcia", 2) }, [], nil)
      NetworkInterfaces.Devices = { "eth-pcmcia" => { "0" => {} } }
      TEST(lambda { NetworkInterfaces.GetFreeDevices("eth-pcmcia", 2) }, [], nil)
      NetworkInterfaces.Devices = { "eth-pcmcia" => { "1" => {} } }
      TEST(lambda { NetworkInterfaces.GetFreeDevices("eth-pcmcia", 2) }, [], nil)

      DUMP("NetworkInterfaces::Locate")
      NetworkInterfaces.Devices = {
        "eth" => { "eth0" => { "BOOTPROTO" => "dhcp" } }
      }
      TEST(lambda { NetworkInterfaces.Locate("BOOTPROTO", "dhcp") }, [], nil)
      NetworkInterfaces.Devices = {
        "eth" => { "eth0" => { "BOOTPROTO" => "" } }
      }
      TEST(lambda { NetworkInterfaces.Locate("BOOTPROTO", "dhcp") }, [], nil)
      NetworkInterfaces.Devices = {
        "eth" => { "eth0" => { "BOOTPROTO" => "static" } }
      }
      TEST(lambda { NetworkInterfaces.Locate("BOOTPROTO", "dhcp") }, [], nil)
      NetworkInterfaces.Devices = {
        "eth" => {
          "eth0" => { "BOOTPROTO" => "static" },
          "eth1" => { "BOOTPROTO" => "dhcp" }
        }
      }
      TEST(lambda { NetworkInterfaces.Locate("BOOTPROTO", "dhcp") }, [], nil)
      NetworkInterfaces.Devices = {
        "eth" => { "eth0" => { "BOOTPROTO" => "static" } },
        "tr"  => { "tr1" => { "BOOTPROTO" => "dhcp" } }
      }
      TEST(lambda { NetworkInterfaces.Locate("BOOTPROTO", "dhcp") }, [], nil)

      DUMP("NetworkInterfaces::UpdateModemSymlink")
      NetworkInterfaces.Devices = {
        "arc" => {
          "arc5" => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" }
        }
      }
      TEST(lambda { NetworkInterfaces.UpdateModemSymlink }, [], nil)
      NetworkInterfaces.Devices = {
        "modem" => {
          "modemc5" => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" }
        }
      }
      TEST(lambda { NetworkInterfaces.UpdateModemSymlink }, [], nil)
      NetworkInterfaces.Devices = {
        "modem" => {
          "modem5" => { "MODEM_DEVICE" => "", "STARTMODE" => "manual" }
        }
      }
      TEST(lambda { NetworkInterfaces.UpdateModemSymlink }, [], nil)
      NetworkInterfaces.Devices = {
        "modem" => {
          "modem5" => {
            "MODEM_DEVICE" => "/dev/modem",
            "STARTMODE"    => "manual"
          }
        }
      }
      TEST(lambda { NetworkInterfaces.UpdateModemSymlink }, [], nil)
      NetworkInterfaces.Devices = {
        "modem" => {
          "modem5" => {
            "MODEM_DEVICE" => "/dev/ttyS1",
            "STARTMODE"    => "manual"
          }
        }
      }
      TEST(lambda { NetworkInterfaces.UpdateModemSymlink }, [], nil)
      @READ = {
        "target" => {
          "lstat"   => { "islink" => true },
          "symlink" => "/dev/ttyS1"
        }
      }
      TEST(lambda { NetworkInterfaces.UpdateModemSymlink }, [@READ], nil)
      @READ = {
        "target" => {
          "lstat"   => { "islink" => true },
          "symlink" => "/dev/ttyS2"
        }
      }
      TEST(lambda { NetworkInterfaces.UpdateModemSymlink }, [@READ], nil)

      DUMP("NetworkInterfaces::List")
      NetworkInterfaces.Devices = {
        "lo" => { "lo" => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" } }
      }
      TEST(lambda { NetworkInterfaces.List("modem") }, [], nil)
      TEST(lambda { NetworkInterfaces.List("netcard") }, [], nil)
      TEST(lambda { NetworkInterfaces.List("") }, [], nil)
      NetworkInterfaces.Devices = {
        "lo"  => { "lo" => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" } },
        "eth" => {
          "eth0" => { "BOOTPROTO" => "DHCP", "STARTMODE" => "manual" }
        }
      }
      TEST(lambda { NetworkInterfaces.List("modem") }, [], nil)
      TEST(lambda { NetworkInterfaces.List("netcard") }, [], nil)
      TEST(lambda { NetworkInterfaces.List("") }, [], nil)
      NetworkInterfaces.Devices = {
        "eth" => { "eth0" => { "BOOTPROTO" => "static" } },
        "tr"  => { "tr1" => { "BOOTPROTO" => "dhcp" } }
      }
      TEST(lambda { NetworkInterfaces.List("modem") }, [], nil)
      TEST(lambda { NetworkInterfaces.List("netcard") }, [], nil)
      TEST(lambda { NetworkInterfaces.List("") }, [], nil)

      nil
    end
  end
end

Yast::NetworkInterfaces2Client.new.main
