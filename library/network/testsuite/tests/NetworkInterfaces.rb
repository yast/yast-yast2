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
  class NetworkInterfacesClient < Client
    def main
      Yast.include self, "testsuite.rb"

      @READ = {}

      TESTSUITE_INIT([@READ], nil)
      Yast.import "NetworkInterfaces"

      DUMP("Combined:")
      @ifcfgs = [
        "eth0",
        "eth1",
        "eth-pcmcia-0",
        "eth-usb-1",
        "tr-pcmcia-1",
        "ippp2",
        "ppp2",
        "lo",
        "eth0#1",
        "eth1#20",
        "eth-pcmcia-0#3",
        "eth-usb-1#0",
        "tr-pcmcia-2#432",
        "ippp2#2",
        "ppp2#2",
        "lo#1",
        "eth1#blah",
        "eth-id-00:07:e9:d5:8e:e8",
        "eth-id-00:07:e9:d5:8e:e8#foo",
        "ip6tnl0",
        "ip6tnl31",
        "mip6mnha3"
      ]

      Builtins.foreach(@ifcfgs) do |ifcfg|
        t = NetworkInterfaces.device_type(ifcfg)
        DUMP(Builtins.sformat("ifcfg-%1, type: %2", ifcfg, t))
      end

      DUMP("CanonicalizeIP:")
      @addresses = [
        # normal cases
        { "IPADDR" => "10.0.0.1/8", "other" => "data" },
        { "IPADDR" => "10.0.0.1", "PREFIXLEN" => "8", "other" => "data" },
        { "IPADDR" => "10.0.0.1", "NETMASK" => "255.0.0.0", "other" => "data" },
        { "BOOTPROTO" => "dhcp" },
        # conflicting cases
        {
          "IPADDR"    => "10.0.0.1/8",
          "PREFIXLEN" => "16",
          "NETMASK"   => "255.255.255.0",
          "other"     => "data"
        },
        # error cases
        nil,
        {},
        { "IPADDR" => "10.0.0.1", "other" => "data" },
      ]
      Builtins.foreach(@addresses) { |address| TEST(lambda do
        NetworkInterfaces.CanonicalizeIP(address)
      end, [], nil) }

      nil
    end
  end
end

Yast::NetworkInterfacesClient.new.main
