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
  class NetworkInterfaces3Client < Client
    def main
      Yast.include self, "testsuite.rb"

      Yast.import "NetworkInterfaces"

      @simple = {
        "WIRELESS_KEY"          => "secret",
        "WIRELESS_KEY_1"        => "secret1",
        "WIRELESS_KEY_2"        => "secret2",
        "WIRELESS_KEY_3"        => "secret3",
        "WIRELESS_KEY_4"        => "", # no need to conceal empty ones
        "WIRELESS_KEY_LENGTH"   => "128", # not a secret
        "WIRELESS_WPA_PSK"      => "secretpsk",
        "WIRELESS_WPA_PASSWORD" => "seekrut",
        "other"                 => "data",
        "_aliases"              => {
          "foo" => {
            "WIRELESS_KEY" => "not masked, should not be here",
            "alias"        => "data"
          }
        }
      }

      DUMP("ConcealSecrets1:")
      @ifcfgs = [
        # normal cases
        @simple,
        # error cases
        nil,
        {}
      ]
      Builtins.foreach(@ifcfgs) { |ifcfg| TEST(lambda do
        NetworkInterfaces.ConcealSecrets1(ifcfg)
      end, [], nil) }

      DUMP("ConcealSecrets:")
      @devss = [
        # normal cases
        {
          "eth"  => {
            "0" => { "other" => "data" },
            "1" => { "other" => "data" }
          },
          "wlan" => {
            "id-00:11:22:33:44:55" => @simple,
            "id-aa:bb:cc:dd:ee:ff" => @simple
          }
        },
        # error cases
        nil,
        {}
      ]
      Builtins.foreach(@devss) { |devs| TEST(lambda do
        NetworkInterfaces.ConcealSecrets(devs)
      end, [], nil) }

      nil
    end
  end
end

Yast::NetworkInterfaces3Client.new.main
