#! /usr/bin/env rspec

inc_dirs = Dir.glob("../../../library/*/src")
inc_dirs.map { |inc_dir| File.expand_path(inc_dir, __FILE__) }
ENV["Y2DIR"] = inc_dirs.join(":")

require "yast"

Yast.import "NetworkInterfaces"

# mocked IPv6 relevant part of loaded ifcfg
IPV6_IFCFG = [
  {
    :data => { "IPADDR" => "2001:15c0:668e::5", "PREFIXLEN" => "48" },
    :expected => { "IPADDR" => "2001:15c0:668e::5", "PREFIXLEN" => "48", "NETMASK" => "" }
  },
  {
    :data => { "IPADDR" => "2001:15c0:668e::5/48", "PREFIXLEN" => "" },
    :expected => { "IPADDR" => "2001:15c0:668e::5", "PREFIXLEN" => "48", "NETMASK" => "" }
  },
  {
    :data => { "IPADDR" => "2a00:8a00:6000:40::451", "PREFIXLEN" => "119" },
    :expected => { "IPADDR" => "2a00:8a00:6000:40::451", "PREFIXLEN" => "119", "NETMASK" => "" }
  }
]

describe Yast::NetworkInterfaces do
  context "Handling IPv6 address" do
    describe "#CanonicalizeIP" do
      it "Sets ipaddr, prefix and empty mask" do
        IPV6_IFCFG.each do |ipv6_ifcfg|
          canonical_ifcfg = Yast::NetworkInterfaces.CanonicalizeIP( ipv6_ifcfg[ :data])
          expect( canonical_ifcfg).to be_eql( ipv6_ifcfg[ :expected])
        end
      end
    end
  end
end
