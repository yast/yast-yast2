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
  class PortAliasesClient < Client
    def main
      Yast.include self, "testsuite.rb"
      # testedfiles: PortAliases

      @READ = {}

      @WRITE = {}

      @EXECUTE = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stdout" => "texar\ntexar",
            "stderr" => ""
          }
        }
      }

      TESTSUITE_INIT([@READ, @WRITE, @EXECUTE], nil)
      Yast.import "PortAliases"

      DUMP("== Allowed Port Aliases ==")
      TEST(->() { PortAliases.IsAllowedPortName("xyz-abc-def") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { PortAliases.IsAllowedPortName("a*a/b+b.c_c-d") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { PortAliases.IsAllowedPortName("!port") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { PortAliases.IsAllowedPortName("1") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { PortAliases.IsAllowedPortName("65535") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)
      TEST(->() { PortAliases.IsAllowedPortName("65536") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)

      DUMP("")
      DUMP("== Service Aliases Included ==")
      Builtins.foreach(
        [
          "22",
          "ssh",
          "25",
          "smtp",
          "53",
          "domain",
          "67",
          "bootps",
          "68",
          "bootpc",
          "69",
          "tftp",
          "80",
          "http",
          "www",
          "www-http",
          "110",
          "pop3",
          "111",
          "sunrpc",
          "123",
          "ntp",
          "137",
          "netbios-ns",
          "138",
          "139",
          "netbios-dgm",
          "143",
          "netbios-ssn",
          "389",
          "ldap",
          "443",
          "https",
          "445",
          "microsoft-ds",
          "500",
          "isakmp",
          "631",
          "ipp",
          "636",
          "ldaps",
          "873",
          "rsync",
          "993",
          "imaps",
          "995",
          "pop3s",
          "3128",
          "ndl-aas",
          "4500",
          "ipsec-nat-t",
          "8080",
          "http-alt"
        ]
      ) do |port|
        TEST(->() { PortAliases.GetListOfServiceAliases(port) },
          [
            @READ,
            @WRITE,
            @EXECUTE
          ], nil)
      end

      DUMP("")
      DUMP("== Service Aliases External ==")
      TEST(->() { PortAliases.GetListOfServiceAliases("333") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)

      DUMP("")
      DUMP("== Port Name ==")
      TEST(->() { PortAliases.IsKnownPortName("www") },
        [
          @READ,
          @WRITE,
          @EXECUTE
        ], nil)

      nil
    end
  end
end

Yast::PortAliasesClient.new.main
