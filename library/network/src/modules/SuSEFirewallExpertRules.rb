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
#
# File:	modules/SuSEFirewallExpertRules.ycp
# Package:	SuSEFirewall configuration
# Summary:	Interface manipulation of /etc/sysconfig/SuSEFirewall (expert rules)
# Authors:	Lukas Ocilka <locilka@suse.cz>
# Flags:	Unstable
#
# $id$
#
# Module for handling SuSEfirewall2 Expert Rules.
require "yast"

module Yast
  class SuSEFirewallExpertRulesClass < Module
    def main
      textdomain "base"

      Yast.import "SuSEFirewall"
      Yast.import "Netmask"
      Yast.import "IP"

      # **
      # Firewall Expert Rulezz
      #
      # ATTENTION: You have to call SuSEFirewall::Read() to read the configuration
      # into the memory and call SuSEFirewall::Write() to write the configuration
      # and restart the firewall service.

      # List of all possible protocols for expert rulezz.
      # _rpc_ expects RPC service name as the destination port then.
      @allowed_expert_protocols = ["udp", "tcp", "icmp", "all", "_rpc_"]

      # used to identify the IPv4 in regexp
      @type_ip4 = "[0123456789]+.[0123456789]+.[0123456789]+.[0123456789]+"
    end

    # Returns list of all protocols accepted by the expert rules.
    #
    # @return	[Array<String>] of protocols
    # @see list <string> allowed_expert_protocols
    def GetAllExpertRulesProtocols
      deep_copy(@allowed_expert_protocols)
    end

    # Function checks the network definition used for firewall expert rules.
    # For backward compatibility. Use IP::CheckNetwork() instead.
    #
    # @param [String] network
    # @return [Boolean] if it is a valid network definition
    def IsValidNetwork(network)
      Builtins.y2internal("Deprecated, please use IP::CheckNetwork() instead")
      IP.CheckNetwork(network)
    end

    # Returns string of valid network definition.
    # Deprecated, please, use IP::ValidNetwork() instead.
    #
    # @return [String] describing the valid network.
    def ValidNetwork
      Builtins.y2internal("Deprecated, please, use IP::ValidNetwork() instead")
      IP.ValidNetwork
    end

    # Adjusts parameters to the acceptable representation
    #
    # @param [Hash{String => String}] params
    # @return	[Hash{String => String}] modified params
    def AdjustParameters(params)
      params = deep_copy(params)
      if Ops.get(params, "network", "") == ""
        Builtins.y2warning("No network defined, using '0/0' instead!")
        Ops.set(params, "network", "0/0")
      end
      if Ops.get(params, "protocol", "") == ""
        Builtins.y2warning("No protocol defined, using 'all' instead!")
        Ops.set(params, "protocol", "all")
      end
      Ops.set(
        params,
        "protocol",
        Builtins.tolower(Ops.get(params, "protocol", ""))
      )

      deep_copy(params)
    end

    # Returns list of rules (maps) describing protocols and ports that are allowed
    # to be accessed from listed hosts. "network" and "protocol" are needed arguments,
    # "dport" and "sport" are optional. Undefined values are returned as empty strings.
    #
    # "network" is either an IP, IP/Netmask or IP/Netmask_Bits where the connection
    # originates; "protocol" defines the transport protocol; "dport" is the destination
    # port on the current host; "sport" is the source port on the client.
    #
    # Port can be port number, port name, port range. Protocol can be 'tcp', 'udp',
    # 'icmp', 'all' or '_rpc_' (dport is then a RPC service name, e.g., ypbind).
    #
    # @see #IP::CheckNetwork()
    #
    #
    # **Structure:**
    #
    #     This might return, e.g., [
    #          // All requests from 80.44.11.22 to TCP port 22
    #     	   $[ "network" : "80.44.11.22",   "protocol" : "tcp", "dport" : "22",  "sport" : ""   ],
    #
    #     // All requests from network 80.44.11.0/24 to UDP port 53 originating on port 53
    #	   $[ "network" : "80.44.11.0/24", "protocol" : "udp", "dport" : "53",  "sport" : "53" ],
    #
    #     // All requests from network 0/0 (everywhere) to TCP port 443
    #	   $[ "network" : "0/0",           "protocol" : "tcp", "dport" : "443", "sport" : ""   ],
    # ]
    #
    # @param [String] zone
    # @return [Array<Hash{String => String>}] of rules
    #
    # @example
    # GetListOfAcceptRules("EXT") -> $[]
    def GetListOfAcceptRules(zone)
      zone = Builtins.toupper(zone)

      # Check the zone
      if !Builtins.contains(SuSEFirewall.GetKnownFirewallZones, zone)
        Builtins.y2error("Unknown firewall zone: %1", zone)
        return nil
      end

      #
      # FW_SERVICES_ACCEPT_EXT, FW_SERVICES_ACCEPT_INT, FW_SERVICES_ACCEPT_DMZ
      # Format: space separated list of net,protocol[,dport][,sport][,other-comma-separated-options]
      #
      rules = Builtins.maplist(
        Builtins.splitstring(SuSEFirewall.GetAcceptExpertRules(zone), " +")
      ) do |one_rule|
        # comma separated
        rule_splitted = Builtins.splitstring(one_rule, ",")
        # additional options after sport (4th entry)
        options_entries_count = Ops.subtract(Builtins.size(rule_splitted), 4)
        {
          "network"  => Ops.get(rule_splitted, 0, ""),
          "protocol" => Ops.get(rule_splitted, 1, ""),
          "dport"    => Ops.get(rule_splitted, 2, ""),
          "sport"    => Ops.get(rule_splitted, 3, ""),
          # additional options if defined (offset 4 and more)
          "options"  => if Ops.greater_than(options_entries_count, 0)
                          Builtins.mergestring(
                            Builtins.sublist(rule_splitted, 4, options_entries_count),
                            ","
                          )
                        else
                          ""
                        end
        }
      end

      # filtering out empty rules
      rules = Builtins.filter(rules) do |one_rule|
        !(Ops.get(one_rule, "network", "") == "" &&
          Ops.get(one_rule, "protocol", "") == "" &&
          Ops.get(one_rule, "dport", "") == "" &&
          Ops.get(one_rule, "sport", "") == "" &&
          Ops.get(one_rule, "options", "") == "")
      end

      deep_copy(rules)
    end

    # Creates a string with one rule definition as described by the given params.
    # All the trailing commas are removed
    #
    # @param [Hash{String => String}] params
    # @return	[String] rule definition
    def CreateRuleFromParams(params)
      params = deep_copy(params)
      # Adjusting params (some empty entries are replaced with $everything value)
      params = AdjustParameters(params)

      # Creating new record
      new_rule = Ops.add(
        Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(Ops.get(params, "network", ""), ","),
                    Ops.get(params, "protocol", "")
                  ),
                  ","
                ),
                Ops.get(params, "dport", "")
              ),
              ","
            ),
            Ops.get(params, "sport", "")
          ),
          ","
        ),
        Ops.get(params, "options", "")
      )

      # Cut out all the trailing commas
      while Builtins.regexpmatch(new_rule, ",+$")
        new_rule = Builtins.regexpsub(new_rule, "(.*),+$", "\\1")
      end

      if new_rule == "0/0,all"
        Builtins.y2warning(
          "Created rule '%1' that allows everything from all networks!",
          new_rule
        )
      end

      new_rule
    end

    # Adds a new accept-rule. Possible keys for parameters are "network",
    # "protocol", "dport" and "sport". Needed are "network" and "protocol".
    #
    # @param [String] zone
    # @param [Hash{String => String}] params
    # @return [Boolean] if successful
    #
    # @see #GetListOfAcceptRules()
    # @see #RemoveAcceptRule()
    #
    # @example
    # AddNewAcceptRule (
    #     "EXT",
    #     $["network":"192.168.0.1/255.255.240.0", "protocol":"tcp", "sport":"22",
    #         "options":"hitcount=3,blockseconds=60,recentname=ssh"]
    # ) -> true
    def AddNewAcceptRule(zone, params)
      params = deep_copy(params)
      zone = Builtins.toupper(zone)

      # Check the zone
      if !Builtins.contains(SuSEFirewall.GetKnownFirewallZones, zone)
        Builtins.y2error("Unknown firewall zone: %1", zone)
        return nil
      end

      # Get all current rules
      current_rules = SuSEFirewall.GetAcceptExpertRules(zone)
      if current_rules.nil?
        Builtins.y2error(
          "Impossible to set new AcceptExpertRule for zone %1",
          zone
        )
        return false
      end

      new_rule = CreateRuleFromParams(params)

      current_rules = Ops.add(
        Ops.add(
          current_rules,
          Ops.greater_than(Builtins.size(current_rules), 0) ? " " : ""
        ),
        new_rule
      )

      SuSEFirewall.SetAcceptExpertRules(zone, current_rules)
    end

    # Removes a single expert firewall rule.
    #
    # @param [String] zone
    # @param [Hash{String => String}] params
    # @return if successful
    #
    # @see GetListOfAcceptRules() for possible keys in map
    # @see #AddNewAcceptRule()
    #
    # @example
    # RemoveAcceptRule (
    #     "EXT",
    #     $["network":"192.168.0.1/255.255.240.0", "protocol":"tcp", "sport":"22"]
    # ) -> true
    def RemoveAcceptRule(zone, params)
      params = deep_copy(params)
      zone = Builtins.toupper(zone)

      # Check the zone
      if !Builtins.contains(SuSEFirewall.GetKnownFirewallZones, zone)
        Builtins.y2error("Unknown firewall zone: %1", zone)
        return nil
      end

      current_rules = SuSEFirewall.GetAcceptExpertRules(zone)
      if current_rules.nil?
        Builtins.y2error(
          "Impossible remove any AcceptExpertRule for zone %1",
          zone
        )
        return false
      end

      current_rules_number = Builtins.size(current_rules)

      # Creating record to be removed
      remove_rule = CreateRuleFromParams(params)

      # Filtering out the record
      current_rules_list = Builtins.splitstring(current_rules, " \n")
      current_rules_list = Builtins.filter(current_rules_list) do |one_rule|
        one_rule != remove_rule && one_rule != "" && one_rule != ","
      end
      current_rules = Builtins.mergestring(current_rules_list, " ")

      SuSEFirewall.SetAcceptExpertRules(zone, current_rules)

      Ops.less_than(
        Builtins.size(SuSEFirewall.GetAcceptExpertRules(zone)),
        current_rules_number
      )
    end

    # Deletes Custom Rule defined by the ID of the rule.
    # The ID is an order of list returned by GetListOfAcceptRules().
    # ID starts at number 0.
    # Every time you delete some rule, the list is, of course, regenerated.
    #
    # @param [String] zone
    # @param [Fixnum] rule_id
    # @return [Boolean] if successful
    #
    # @example
    # 	DeleteRuleID (0) -> true
    #
    # @see #GetListOfAcceptRules()
    def DeleteRuleID(zone, rule_id)
      # Check the zone
      if !Builtins.contains(SuSEFirewall.GetKnownFirewallZones, zone)
        Builtins.y2error("Unknown firewall zone: %1", zone)
        return nil
      end

      current_rules = SuSEFirewall.GetAcceptExpertRules(zone)
      if current_rules.nil?
        Builtins.y2error(
          "Impossible remove any AcceptExpertRule for zone %1",
          zone
        )
        return false
      end

      current_rules_list = Builtins.splitstring(current_rules, " \n")
      if !Ops.get(current_rules_list, rule_id).nil?
        current_rules_list = Builtins.remove(current_rules_list, rule_id)
        current_rules = Builtins.mergestring(current_rules_list, " ")
        SuSEFirewall.SetAcceptExpertRules(zone, current_rules)
        return true
      else
        Builtins.y2error(
          "Cannot remove %1, such entry does not exist.",
          rule_id
        )
        return false
      end
    end

    publish function: :GetAllExpertRulesProtocols, type: "list <string> ()"
    publish function: :IsValidNetwork, type: "boolean (string)"
    publish function: :ValidNetwork, type: "string ()"
    publish function: :GetListOfAcceptRules, type: "list <map <string, string>> (string)"
    publish function: :AddNewAcceptRule, type: "boolean (string, map <string, string>)"
    publish function: :RemoveAcceptRule, type: "boolean (string, map <string, string>)"
    publish function: :DeleteRuleID, type: "boolean (string, integer)"
  end

  SuSEFirewallExpertRules = SuSEFirewallExpertRulesClass.new
  SuSEFirewallExpertRules.main
end
