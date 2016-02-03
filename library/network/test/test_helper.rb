require_relative "../../../test/test_helper.rb"
require "fileutils"

Yast.import "NetworkInterfaces"

module NetworkStubs
  IPV6_IFCFG = [
    {
      data:     { "IPADDR" => "2001:15c0:668e::5", "PREFIXLEN" => "48" },
      expected: { "IPADDR" => "2001:15c0:668e::5", "PREFIXLEN" => "48", "NETMASK" => "" }
    },
    {
      data:     { "IPADDR" => "2001:15c0:668e::5/48", "PREFIXLEN" => "" },
      expected: { "IPADDR" => "2001:15c0:668e::5", "PREFIXLEN" => "48", "NETMASK" => "" }
    },
    {
      data:     { "IPADDR" => "2a00:8a00:6000:40::451", "PREFIXLEN" => "119" },
      expected: { "IPADDR" => "2a00:8a00:6000:40::451", "PREFIXLEN" => "119", "NETMASK" => "" }
    }
  ]

  # mocked IPv6 relevant part of loaded ifcfg
  IPV4_IFCFG = [
    {
      data:     { "IPADDR" => "TheIP", "PREFIXLEN" => "24" },
      expected: { "IPADDR" => "TheIP", "PREFIXLEN" => "24", "NETMASK" => "" }
    },
    {
      data:     { "IPADDR" => "TheIP/24", "PREFIXLEN" => "" },
      expected: { "IPADDR" => "TheIP", "PREFIXLEN" => "24", "NETMASK" => "" }
    },
    {
      data:     { "IPADDR" => "TheIP", "PREFIXLEN" => "119" },
      expected: { "IPADDR" => "TheIP", "PREFIXLEN" => "119", "NETMASK" => "" }
    },
    {
      data:     { "IPADDR" => "10.0.0.1", "other" => "data" },
      expected: {
        "IPADDR"    => "10.0.0.1",
        "PREFIXLEN" => "32",
        "NETMASK"   => "255.255.255.255",
        "other"     => "data"
      }
    },
    {
      data:     { "BOOTPROTO" => "dhcp" },
      expected: { "BOOTPROTO" => "dhcp" }
    }
  ]

  MOCKUP_SYSFS_INTERFACES = {
    wls3p0: {
      sysfs:    "/sys/class/net/wls3p0/wireless",
      eth_type: "wlan"
    },
    wls3p1: {
      sysfs:    "/sys/class/net/wls3p1/phy80211",
      eth_type: "wlan"
    },
    br0:    {
      sysfs:    "/sys/class/net/br0/bridge",
      eth_type: "br"
    },
    bond0:  {
      sysfs:    "/sys/class/net/bond0/bonding",
      eth_type: "bond"
    },
    tun0:   {
      sysfs:    "/sys/class/net/tun0/tun_flags",
      eth_type: "tap"
    },
    vlan0:  {
      sysfs:    "/proc/net/vlan/vlan0",
      eth_type: "vlan"
    },
    dummy0: {
      sysfs:    "/sys/devices/virtual/net/dummy0",
      eth_type: "dummy"
    }
  }
end
