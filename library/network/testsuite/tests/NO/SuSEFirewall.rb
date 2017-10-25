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
  class SuSEFirewallClient < Client
    def main
      Yast.include self, "testsuite.rb"
      # testedfiles: SuSEFirewall

      @SuSEfirewall2 = {
        "FW_ALLOW_FW_BROADCAST_DMZ"  => "no",
        "FW_ALLOW_FW_BROADCAST_EXT"  => "no",
        "FW_ALLOW_FW_BROADCAST_INT"  => "no",
        "FW_CONFIGURATIONS_DMZ"      => "aaa-bbb",
        "FW_CONFIGURATIONS_EXT"      => "aaa-bbb ab-ab-ab aa-aa-aa bb-bb-bb",
        "FW_CONFIGURATIONS_INT"      => "",
        "FW_DEV_DMZ"                 => "",
        "FW_DEV_EXT"                 => "eth6 special-string eth8",
        "FW_DEV_INT"                 => "dsl0",
        "FW_FORWARD_MASQ"            => "",
        "FW_IGNORE_FW_BROADCAST_DMZ" => "no",
        "FW_IGNORE_FW_BROADCAST_EXT" => "yes",
        "FW_IGNORE_FW_BROADCAST_INT" => "no",
        "FW_IPSEC_TRUST"             => "no",
        "FW_LOAD_MODULES"            => "\n\n\n",
        "FW_LOG_ACCEPT_ALL"          => "no",
        "FW_LOG_ACCEPT_CRIT"         => "yes",
        "FW_LOG_DROP_ALL"            => "no",
        "FW_LOG_DROP_CRIT"           => "yes",
        "FW_MASQUERADE"              => "no",
        "FW_PROTECT_FROM_INT"        => "no",
        "FW_ROUTE"                   => "no",
        "FW_SERVICES_DMZ_IP"         => "",
        "FW_SERVICES_DMZ_RPC"        => "",
        "FW_SERVICES_DMZ_TCP"        => "",
        "FW_SERVICES_DMZ_UDP"        => "",
        "FW_SERVICES_EXT_IP"         => "",
        "FW_SERVICES_EXT_RPC"        => "",
        "FW_SERVICES_EXT_TCP"        => "",
        "FW_SERVICES_EXT_UDP"        => "",
        "FW_SERVICES_INT_IP"         => "",
        "FW_SERVICES_INT_RPC"        => "",
        "FW_SERVICES_INT_TCP"        => "",
        "FW_SERVICES_INT_UDP"        => "",
        "enable_firewall"            => false,
        "start_firewall"             => false
      }

      # data have been stolen from mvidner's testsuite 'NetworkDevices2.ycp'
      @Network = {
        "section" => {
          "arc5"   => nil,
          "atm5"   => nil,
          "ci5"    => nil,
          "ctc5"   => nil,
          "dummy5" => nil,
          "escon5" => nil,
          "eth5"   => nil,
          "eth6"   => nil,
          "eth7"   => nil,
          "eth8"   => nil,
          "eth9"   => nil,
          "fddi5"  => nil,
          "hippi5" => nil,
          "hsi5"   => nil,
          "ippp5"  => nil,
          "iucv5"  => nil,
          "lo"     => nil,
          "myri5"  => nil,
          "ppp5"   => nil,
          "tr5"    => nil,
          "tr~"    => nil
        },
        "value"   => {
          "arc5"   => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
          "atm5"   => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
          "ci5"    => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
          "ctc5"   => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
          "dummy5" => {
            "BOOTPROTO" => "static",
            "IPADDR"    => "1.2.3.4",
            "NETMASK"   => "255.0.0.0",
            "STARTMODE" => "manual"
          },
          "escon5" => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
          "eth5"   =>
                      # "IPADDR_x":"1.1.1.1", "NETMASK_x":"0.0.0.0"
                      { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
          "eth6"   => {
            "BOOTPROTO" => "static",
            "IPADDR"    => "1.2.3.4",
            "STARTMODE" => "manual"
          },
          "eth7"   => { "STARTMODE" => "manual" },
          "eth8"   => { "IPADDR" => "1.2.3.4/8", "STARTMODE" => "manual" },
          "eth9"   => {
            "IPADDR"    => "1.2.3.4",
            "PREFIXLEN" => "8",
            "STARTMODE" => "manual"
          },
          "fddi5"  => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
          "hippi5" => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
          "hsi5"   => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
          "ippp5"  => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
          "iucv5"  => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
          "lo"     =>
                      # "IPADDR_1":"7.7.7.7"
                      {
                        "BROADCAST" => "127.255.255.255",
                        "IPADDR"    => "127.0.0.1",
                        "NETMASK"   => "255.0.0.0",
                        "NETWORK"   => "127.0.0.0",
                        "STARTMODE" => "onboot"
                      },
          "myri5"  => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
          "ppp5"   => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" },
          "tr5"    => { "BOOTPROTO" => "dhcp", "STARTMODE" => "manual" }
        }
      }

      @READ = {
        "sysconfig" => { "SuSEfirewall2" => @SuSEfirewall2 },
        "network"   => @Network,
        "probe"     => { "system" => [] },
        "target"    => { "tmpdir" => "/tmp" }
      }

      @WRITE = {}

      @EXECUTE = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stdout" => "",
            "stderr" => ""
          },
          "bash"        => 0
        }
      }

      TESTSUITE_INIT([@READ, @WRITE, @EXECUTE], nil)
      Yast.import "SuSEFirewall"

      # Configuration must be read!
      SuSEFirewall.Read
      # initialize to disabled, not running
      SuSEFirewall.SetEnableService(false)
      SuSEFirewall.SetStartService(false)

      DUMP("== SuSEfirewall2 service ==")
      TEST(->() { SuSEFirewall.GetEnableService }, [@READ, @WRITE, @EXECUTE], nil)
      TEST(->() { SuSEFirewall.GetStartService }, [@READ, @WRITE, @EXECUTE], nil)
      TEST(->() { SuSEFirewall.SetEnableService(true) },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.SetStartService(true) },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetEnableService }, [@READ, @WRITE, @EXECUTE], nil)
      TEST(->() { SuSEFirewall.GetStartService }, [@READ, @WRITE, @EXECUTE], nil)

      DUMP("")
      DUMP("== Read/Write ==")
      TEST(->() { SuSEFirewall.Read }, [@READ, @WRITE, @EXECUTE], nil)
      TEST(->() { SuSEFirewall.Write }, [@READ, @WRITE, @EXECUTE], nil)

      DUMP("")
      DUMP("== Import/Export ==")
      TEST(->() { SuSEFirewall.Import(@SuSEfirewall2) },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.Export }, [@READ, @WRITE, @EXECUTE], nil)

      DUMP("")
      DUMP("== Firewall behaviour ==")
      TEST(->() { SuSEFirewall.GetAllKnownInterfaces },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetKnownFirewallZones },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)

      DUMP("")
      DUMP("== Interfaces Handling ==")
      TEST(->() { SuSEFirewall.GetInterfacesInZone("EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.AddInterfaceIntoZone("undefined", "EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.AddInterfaceIntoZone("eth9", "EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetInterfacesInZone("EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetSpecialInterfacesInZone("EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)

      TEST(->() { SuSEFirewall.AddInterfaceIntoZone("eth9", "DMZ") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.RemoveInterfaceFromZone("eth6", "EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.RemoveInterfaceFromZone("undefined", "EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetInterfacesInZone("EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetInterfacesInZone("DMZ") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetSpecialInterfacesInZone("EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)

      TEST(->() { SuSEFirewall.GetZoneOfInterface("-none-") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetZoneOfInterface("eth9") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetZonesOfInterfaces(["eth9", "dsl0"]) },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)

      DUMP("")
      DUMP("== Logging settings ==")
      TEST(->() { SuSEFirewall.GetLoggingSettings("ACCEPT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetLoggingSettings("DROP") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.SetLoggingSettings("ACCEPT", "ALL") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.SetLoggingSettings("DROP", "NONE") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetLoggingSettings("ACCEPT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetLoggingSettings("DROP") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)

      TEST(->() { SuSEFirewall.GetIgnoreLoggingBroadcast("INT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetIgnoreLoggingBroadcast("EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetIgnoreLoggingBroadcast("DMZ") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.SetIgnoreLoggingBroadcast("INT", "yes") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.SetIgnoreLoggingBroadcast("EXT", "no") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.SetIgnoreLoggingBroadcast("DMZ", "yes") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetIgnoreLoggingBroadcast("INT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetIgnoreLoggingBroadcast("EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.GetIgnoreLoggingBroadcast("DMZ") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)

      DUMP("")
      DUMP("== Ports handling ==")
      TEST(->() { SuSEFirewall.HaveService("www", "TCP", "EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.AddService("www", "TCP", "EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.HaveService("80", "TCP", "EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.RemoveService("www-http", "TCP", "EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { SuSEFirewall.HaveService("80", "TCP", "EXT") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)

      DUMP("")
      DUMP("== Broadcast handling ==")
      TEST(->() { SuSEFirewall.GetBroadcastAllowedPorts },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(lambda do
        SuSEFirewall.SetBroadcastAllowedPorts(
          "INT" => [], "DMZ" => ["5", "3", "1"], "EXT" => ["22", "33", "44"]
        )
      end, [
        @READ,
        @WRITE,
        @EXECUTE
      ], nil)
      TEST(->() { SuSEFirewall.GetBroadcastAllowedPorts },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)

      DUMP("")
      DUMP("== Masquerade handling ==")
      TEST(->() { SuSEFirewall.GetMasquerade }, [@READ, @WRITE, @EXECUTE], nil)
      TEST(->() { SuSEFirewall.SetMasquerade(true) }, [@READ, @WRITE, @EXECUTE], nil)
      TEST(->() { SuSEFirewall.GetMasquerade }, [@READ, @WRITE, @EXECUTE], nil)

      @EXECUTE_OK = deep_copy(@EXECUTE)
      if Ops.get_map(@EXECUTE_OK, "target", {}) == {}
        Ops.set(@EXECUTE_OK, "target", {})
      end
      Ops.set(
        @EXECUTE_OK,
        ["target", "bash_output"],
        "exit" => 0, "stdout" => "Some warnings about IPv6", "stderr" => ""
      )

      @EXECUTE_ERR = deep_copy(@EXECUTE)
      if Ops.get_map(@EXECUTE_ERR, "target", {}) == {}
        Ops.set(@EXECUTE_ERR, "target", {})
      end
      Ops.set(
        @EXECUTE_ERR,
        ["target", "bash_output"],

        "exit"   => 35,
        "stdout" => "Some warnings about IPv6",
        "stderr" => "Some errors!"

      )

      DUMP("")
      DUMP("== Service Stop / Start ==")
      TEST(->() { SuSEFirewall.StopServices }, [@READ, @WRITE, @EXECUTE_OK], nil)
      TEST(->() { SuSEFirewall.StopServices }, [@READ, @WRITE, @EXECUTE_OK], nil)
      TEST(->() { SuSEFirewall.StartServices }, [@READ, @WRITE, @EXECUTE_ERR], nil)
      TEST(->() { SuSEFirewall.StartServices }, [@READ, @WRITE, @EXECUTE_ERR], nil)

      DUMP("")
      DUMP("== Additional Kernel Modules ==")
      TEST(->() { SuSEFirewall.GetFirewallKernelModules },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      # empty modules, nil modules
      TEST(lambda do
        SuSEFirewall.SetFirewallKernelModules(
          ["module_a", nil, "module_b", "", "module_c", ""]
        )
      end, [
        @READ,
        @WRITE,
        @EXECUTE
      ], nil)
      TEST(->() { SuSEFirewall.GetFirewallKernelModules },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(lambda do
        SuSEFirewall.SetFirewallKernelModules(
          ["module_z", "module_x", "module_y"]
        )
      end, [
        @READ,
        @WRITE,
        @EXECUTE
      ], nil)
      TEST(->() { SuSEFirewall.GetFirewallKernelModules },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      # more modules in one entry - separated by space or tab
      TEST(lambda do
        SuSEFirewall.SetFirewallKernelModules(
          ["module_a module_z", "module_y\tmodule_x", "module_b module_c"]
        )
      end, [
        @READ,
        @WRITE,
        @EXECUTE
      ], nil)
      TEST(->() { SuSEFirewall.GetFirewallKernelModules },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)

      nil
    end
  end
end

Yast::SuSEFirewallClient.new.main
