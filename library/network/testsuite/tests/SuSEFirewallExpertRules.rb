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
  class SuSEFirewallExpertRulesClient < Client
    def main
      Yast.include self, "testsuite.rb"
      # testedfiles: SuSEFirewallExpertRules

      Yast.import "SuSEFirewallExpertRules"

      DUMP("== IsValidNetwork ==")

      @valid_network_definitions = [
        "192.168.0.1",
        "192.168.0.0/24",
        "192.168.0.1/32",
        "192.168.0.0/255.255.0.0",
        "192.168.0.0/255.255.224.0",
        "0/0",
        "192.168.0.1/16",
        "192.168.0.1/0"
      ]

      @invalid_network_definitions = [
        "192.168.0.355",
        "192.168.0.0/255.255.333.0",
        "192.168.0.1/888",
        "192.168.0.1/33"
      ]

      DUMP("All these should be *valid* (true):")
      Builtins.foreach(@valid_network_definitions) do |check_this|
        TEST(->() { SuSEFirewallExpertRules.IsValidNetwork(check_this) }, [], nil)
      end

      DUMP("All these should be *invalid* (false):")
      Builtins.foreach(@invalid_network_definitions) do |check_this|
        TEST(->() { SuSEFirewallExpertRules.IsValidNetwork(check_this) }, [], nil)
      end

      DUMP("Testing adding/reading expert rules")
      # Rules are empty at the beginning
      TEST(->() { SuSEFirewallExpertRules.GetListOfAcceptRules("EXT") }, [], nil)

      TEST(lambda do
        SuSEFirewallExpertRules.AddNewAcceptRule(
          "EXT",
          
            "network"  => "192.168.0.1/255.255.240.0",
            "protocol" => "tcp",
            "sport"    => "22",
            "options"  => "hitcount=3,blockseconds=60,recentname=ssh"
          
        )
      end, [], nil)
      TEST(->() { SuSEFirewallExpertRules.GetListOfAcceptRules("EXT") }, [], nil)

      TEST(lambda do
        SuSEFirewallExpertRules.AddNewAcceptRule(
          "EXT",
          
            "network"  => "192.168.0.1/255.255.240.0",
            "protocol" => "tcp",
            "options"  => "whatever=1"
          
        )
      end, [], nil)
      TEST(->() { SuSEFirewallExpertRules.GetListOfAcceptRules("EXT") }, [], nil)

      # Deleting by rule ID (offset in list)
      TEST(->() { SuSEFirewallExpertRules.DeleteRuleID("EXT", 0) }, [], nil)
      TEST(->() { SuSEFirewallExpertRules.GetListOfAcceptRules("EXT") }, [], nil)

      DUMP("Cannot remove rule that doesn't exist")
      TEST(lambda do
        SuSEFirewallExpertRules.RemoveAcceptRule(
          "EXT",
           "network" => "192.168.0.1/255.255.240.0", "protocol" => "tcp" 
        )
      end, [], nil)
      TEST(->() { SuSEFirewallExpertRules.GetListOfAcceptRules("EXT") }, [], nil)

      # Now "options" match too
      TEST(lambda do
        SuSEFirewallExpertRules.RemoveAcceptRule(
          "EXT",
          
            "network"  => "192.168.0.1/255.255.240.0",
            "protocol" => "tcp",
            "options"  => "whatever=1"
          
        )
      end, [], nil)
      TEST(->() { SuSEFirewallExpertRules.GetListOfAcceptRules("EXT") }, [], nil)

      DUMP("Adding special rule allowed 'from all networks'")
      TEST(lambda do
        SuSEFirewallExpertRules.AddNewAcceptRule(
          "EXT",
           "protocol" => "UDP", "sport" => "888" 
        )
      end, [], nil)
      TEST(->() { SuSEFirewallExpertRules.GetListOfAcceptRules("EXT") }, [], nil)

      # Special all-IPv4-networks-(only) rule
      TEST(lambda do
        SuSEFirewallExpertRules.AddNewAcceptRule(
          "EXT",
           "protocol" => "TCP", "sport" => "999", "network" => "0.0.0.0/0" 
        )
      end, [], nil)
      TEST(->() { SuSEFirewallExpertRules.GetListOfAcceptRules("EXT") }, [], nil)

      DUMP("== Done ==")

      nil
    end
  end
end

Yast::SuSEFirewallExpertRulesClient.new.main
