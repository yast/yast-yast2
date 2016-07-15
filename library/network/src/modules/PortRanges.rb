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
# File:	modules/PortRanges.ycp
# Package:	SuSEFirewall configuration
# Summary:	Checking and manipulation with port ranges (iptables).
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# $id$
#
# Module for handling port ranges.
require "yast"

module Yast
  # Tools for ranges of network ports, as used by iptables for firewalling.
  #
  # A Port Range is a string of two numbers separated with a colon: "3000:3010".
  # The range includes both ends. The numbers are nonnegative integers.
  #
  # A *Valid* Port Range is an ascending pair of numbers between 1..65535.
  class PortRangesClass < Module
    def main
      textdomain "base"

      Yast.import "PortAliases"

      # Variable for ReportOnlyOnce() function
      @report_only_once = []

      # Maximal number of port number, they are in the interval 1-65535 included.
      # The very same value should appear in SuSEFirewall::max_port_number.
      @max_port_number = 65_535
    end

    # @!group Helpers

    # Report the error, warning, message only once.
    # Stores the error, warning, message in memory.
    # This is just a helper function that could avoid from filling y2log up with
    # a lot of the very same messages - 'foreach()' is a very powerful builtin.
    #
    # @param string error, warning or message
    # @return [Boolean] whether the message should be reported or not
    #
    # @example
    #	string error = sformat("Port number %1 is invalid.", port_nr);
    #	if (ReportOnlyOnce(error)) y2error(error);
    def ReportOnlyOnce(what_to_report)
      return false if Builtins.contains(@report_only_once, what_to_report)

      @report_only_once = Builtins.add(@report_only_once, what_to_report)
      true
    end
    # @!endgroup

    # Port Ranges -->

    # Function returns where the string parameter is a port range.
    # Port ranges are defined by the syntax "min_port_number:max_port_number".
    # Port range means that these maximum and minimum ports define the range
    # of currency in Firewall. Ports defining the range are included in it.
    # This function doesn't check whether the port range is valid or not.
    #
    # @param string to be checked
    # @return [Boolean] whether the checked string is a port range or not
    #
    # @see #IsValidPortRange()
    #
    # @example
    #     IsPortRange("34:38")      -> true
    #     IsPortRange("0:38")       -> true
    #     IsPortRange("port-range") -> false
    #     IsPortRange("19-22")      -> false
    def IsPortRange(check_this)
      if Builtins.regexpmatch(check_this, "^[0123456789]+:[0123456789]+$")
        return true
      end
      false
    end

    # Checks whether the port range is valid.
    #
    # @param [String] port_range
    # @return [Boolean] if it is valid
    #
    # @see #IsPortRange()
    #
    # @example
    #     IsValidPortRange("54:135") -> true  // valid
    #     IsValidPortRange("135:54") -> false // reverse order
    #     IsValidPortRange("0:135")  -> false // cannot be from 0
    #     IsValidPortRange("135")    -> false // cannot be one number
    #     IsValidPortRange("54-135") -> false // wrong separator
    def IsValidPortRange(port_range)
      # not a port range
      if !IsPortRange(port_range)
        warning = Builtins.sformat("Not a port-range %1", port_range)
        Builtins.y2milestone(warning) if ReportOnlyOnce(warning)

        return false
      end

      min_pr = Builtins.tointeger(
        Builtins.regexpsub(port_range, "^([0123456789]+):.*$", "\\1")
      )
      max_pr = Builtins.tointeger(
        Builtins.regexpsub(port_range, "^.*:([0123456789]+)$", "\\1")
      )

      # couldn't extract two integers
      if min_pr.nil? && max_pr.nil?
        warning = Builtins.sformat(
          "Wrong port-range: '%1':'%2'",
          min_pr,
          max_pr
        )
        Builtins.y2warning(warning) if ReportOnlyOnce(warning)

        return false
      end

      # Checking the minimal port number in the port-range
      # wrong range
      if Ops.less_than(min_pr, 1) || Ops.greater_than(min_pr, @max_port_number)
        warning = Builtins.sformat("Wrong port-range definition %1", port_range)
        Builtins.y2warning(warning) if ReportOnlyOnce(warning)

        return false
      end

      # Checking the maximal port number in the port-range
      # wrong range
      if Ops.less_than(max_pr, 1) || Ops.greater_than(max_pr, @max_port_number)
        warning = Builtins.sformat("Wrong port-range definition %1", port_range)
        Builtins.y2warning(warning) if ReportOnlyOnce(warning)

        return false
      end

      # wrong range
      if Ops.greater_or_equal(min_pr, max_pr)
        warning = Builtins.sformat("Wrong port-range definition %1", port_range)
        Builtins.y2warning(warning) if ReportOnlyOnce(warning)

        return false
      end

      true
    end

    # Function returns where the port name or port number is included in the
    # list of port ranges. Port ranges must be defined as a string with format
    # "min_port_number:max_port_number".
    #
    # @param [String] port a number or a name (see PortAliasesClass)
    # @param [Array<String>] port_ranges
    # @return [Boolean]
    #
    # @example
    #     PortIsInPortranges ("130",  ["100:150","10:30"]) -> true
    #     PortIsInPortranges ("30",   ["100:150","10:20"]) -> false
    #     PortIsInPortranges ("pop3", ["100:150","10:30"]) -> true
    #     PortIsInPortranges ("http", ["100:150","10:20"]) -> false
    def PortIsInPortranges(port, port_ranges)
      port_ranges = deep_copy(port_ranges)
      return false if Builtins.size(port_ranges) == 0

      ret = false

      port_number = PortAliases.GetPortNumber(port)

      Builtins.foreach(port_ranges) do |port_range|
        # is portrange really a port range?
        if IsValidPortRange(port_range)
          min_pr = Builtins.tointeger(
            Builtins.regexpsub(port_range, "^([0123456789]+):.*$", "\\1")
          )
          max_pr = Builtins.tointeger(
            Builtins.regexpsub(port_range, "^.*:([0123456789]+)$", "\\1")
          )

          # is the port inside?
          if Ops.less_or_equal(min_pr, max_pr) &&
              Ops.less_or_equal(min_pr, port_number) &&
              Ops.less_or_equal(port_number, max_pr)
            ret = true

            raise Break # break the loop, match found
          end
        end
      end if !port_number.nil?

      ret
    end

    # Function divides list of ports to the map of ports and port ranges.
    # If with_aliases is 'true' it also returns ports wit their port aliases.
    # Port ranges are not affected with it.
    #
    # @param [Array<String>] unsorted_ports
    # @param [Boolean] with_aliases should names of single ports
    #   be translated to numbers
    # @return [Hash{String => Array<String>}] categorized ports:
    #   {
    #     "ports"       => [ list of ports ],
    #     "port_ranges" => [ list of port ranges ],
    #   }
    def DividePortsAndPortRanges(unsorted_ports, with_aliases)
      unsorted_ports = deep_copy(unsorted_ports)
      ret = {}

      Builtins.foreach(unsorted_ports) do |port|
        # port range
        if IsPortRange(port)
          Ops.set(
            ret,
            "port_ranges",
            Builtins.add(Ops.get(ret, "port_ranges", []), port)
          )
        # is a normal port
        # find also aliases
        elsif with_aliases
          Ops.set(
            ret,
            "ports",
            Convert.convert(
              Builtins.union(
                Ops.get(ret, "ports", []),
                PortAliases.GetListOfServiceAliases(port)
              ),
              from: "list",
              to:   "list <string>"
            )
          )
          # only add the port itself
        else
          Ops.set(ret, "ports", Builtins.add(Ops.get(ret, "ports", []), port))
        end
      end

      deep_copy(ret)
    end

    # Function creates a port range from min and max params. Max must be bigger than min.
    # If something is wrong, it returns an empty string.
    #
    # @param integer min_port
    # @param integer max_port
    # @return [String] new port range
    #
    # @example
    #    CreateNewPortRange(10, 20) # => "10:20"
    #    CreateNewPortRange(10, 10) # => "10"
    #    CreateNewPortRange(0,  20) # => ""
    #    CreateNewPortRange(20, 10) # => ""
    def CreateNewPortRange(min_pr, max_pr)
      if min_pr.nil? || min_pr == 0
        Builtins.y2error(
          "Wrong definition of the starting port '%1', it must be between 1 and 65535",
          min_pr
        )
        return ""
      elsif max_pr.nil? || max_pr == 0 || Ops.greater_than(max_pr, 65_535)
        Builtins.y2error(
          "Wrong definition of the ending port '%1', it must be between 1 and 65535",
          max_pr
        )
        return ""
      end

      # max and min are the same, this is not a port range
      if min_pr == max_pr
        Builtins.tostring(min_pr)
      # right port range
      elsif Ops.less_than(min_pr, max_pr)
        Ops.add(
          Ops.add(Builtins.tostring(min_pr), ":"),
          Builtins.tostring(max_pr)
        )
      # min is bigger than max
      else
        Builtins.y2error(
          "Starting port '%1' cannot be bigger than ending port '%2'",
          min_pr,
          max_pr
        )
        ""
      end
    end

    # Function removes port number from all port ranges. Port must be in its numeric
    # form.
    # A port range may be a single port, that's OK.
    # Or a non-port, then it will be kept.
    #
    # @see #PortAliases::GetPortNumber()
    # @param [Fixnum] port_number to be removed
    # @param [Array<String>] port_ranges
    # @return [Array<String>] of filtered port_ranges
    #
    # @example
    #     RemovePortFromPortRanges(25, ["19:88", "152:160"]) -> ["19:24", "26:88", "152:160"]
    def RemovePortFromPortRanges(port_number, port_ranges)
      port_ranges = deep_copy(port_ranges)
      # Checking necessarity of filtering and params
      return deep_copy(port_ranges) if port_ranges.nil? || port_ranges == []
      return deep_copy(port_ranges) if port_number.nil? || port_number == 0

      Builtins.y2milestone(
        "Removing port %1 from port ranges %2",
        port_number,
        port_ranges
      )

      ret = []
      # Checking every port range alone
      Builtins.foreach(port_ranges) do |port_range|
        # Port range might be now only "port"
        if !IsPortRange(port_range)
          # If the port doesn't match the ~port_range...
          if Builtins.tostring(port_number) != port_range
            ret = Builtins.add(ret, port_range)
          end
          # If matches, it isn't added (it is filtered)
          # Modify the port range when the port is included
        elsif PortIsInPortranges(Builtins.tostring(port_number), [port_range])
          min_pr = Builtins.tointeger(
            Builtins.regexpsub(port_range, "^([0123456789]+):.*$", "\\1")
          )
          max_pr = Builtins.tointeger(
            Builtins.regexpsub(port_range, "^.*:([0123456789]+)$", "\\1")
          )

          # Port matches the min. value of port range
          if port_number == min_pr
            ret = Builtins.add(
              ret,
              CreateNewPortRange(Ops.add(port_number, 1), max_pr)
            )
            # Port matches the max. value of port range
          elsif port_number == max_pr
            ret = Builtins.add(
              ret,
              CreateNewPortRange(min_pr, Ops.subtract(port_number, 1))
            )
            # Port is inside the port range, split it up
          else
            ret = Builtins.add(
              ret,
              CreateNewPortRange(Ops.add(port_number, 1), max_pr)
            )
            ret = Builtins.add(
              ret,
              CreateNewPortRange(min_pr, Ops.subtract(port_number, 1))
            )
          end
          # Port isn't in the port range, adding the current port range
        else
          ret = Builtins.add(ret, port_range)
        end
      end

      Builtins.y2milestone("Result: %1", ret)

      deep_copy(ret)
    end

    # Function tries to flatten services into the minimal list.
    # If ports are already mentioned inside port ranges, they are dropped.
    #
    # @param old_list [Array<String>] port numbers, names, or ranges
    # @param protocol [String] old_list is returned
    #   unchanged if protocol is other than "TCP" or "UDP"
    # @return [Array<String>] of flattened services and port ranges
    def FlattenServices(old_list, protocol)
      old_list = deep_copy(old_list)
      if !Builtins.contains(["TCP", "UDP"], protocol)
        message = Builtins.sformat(
          "Protocol %1 doesn't support port ranges, skipping...",
          protocol
        )
        Builtins.y2milestone(message) if ReportOnlyOnce(message)
        return deep_copy(old_list)
      end

      new_list = []
      list_of_ranges = []
      # Using port number, we can remove ports mentioned in port ranges
      ports_to_port_numbers = {}
      # Using this we can remove ports mentioned more than once
      port_numbers_to_port_names = {}

      Builtins.foreach(old_list) do |one_item|
        # Port range
        if IsPortRange(one_item)
          list_of_ranges = Builtins.add(list_of_ranges, one_item)
        else
          port_number = PortAliases.GetPortNumber(one_item)
          # Cannot find port number for this port, it is en error of the configuration
          if port_number.nil?
            Builtins.y2warning(
              "Unknown port %1 but leaving it in the configuration.",
              one_item
            )
            new_list = Builtins.add(new_list, one_item)
            # skip the 'nil' port number
            next
          end
          Ops.set(ports_to_port_numbers, one_item, port_number)
          Ops.set(
            port_numbers_to_port_names,
            port_number,
            Builtins.add(
              Ops.get(port_numbers_to_port_names, port_number, []),
              one_item
            )
          )
        end
      end

      Builtins.foreach(port_numbers_to_port_names) do |port_number, _port_names|
        # Port is not in any defined port range
        if !PortIsInPortranges(Builtins.tostring(port_number), list_of_ranges)
          # Port - 1 IS in some port range
          if PortIsInPortranges(
            Builtins.tostring(Ops.subtract(port_number, 1)),
            list_of_ranges
          )
            # Creating fake port range, to be joined with another one
            list_of_ranges = Builtins.add(
              list_of_ranges,
              CreateNewPortRange(Ops.subtract(port_number, 1), port_number)
            )
            # Port + 1 IS in some port range
          elsif PortIsInPortranges(
            Builtins.tostring(Ops.add(port_number, 1)),
            list_of_ranges
          )
            # Creating fake port range, to be joined with another one
            list_of_ranges = Builtins.add(
              list_of_ranges,
              CreateNewPortRange(port_number, Ops.add(port_number, 1))
            )
            # Port is not in any port range and also it cannot be joined with any one
          else
            # Port names of this port
            used_port_names = Ops.get(
              port_numbers_to_port_names,
              port_number,
              []
            )
            if Ops.greater_than(Builtins.size(used_port_names), 0)
              new_list = Builtins.add(new_list, Ops.get(used_port_names, 0, ""))
            else
              Builtins.y2milestone(
                "No port name for port number %1. Adding %1...",
                port_number
              )
              # There are no port names (hmm?), adding port number
              new_list = Builtins.add(new_list, Builtins.tostring(port_number))
            end
          end
          # Port is in a port range
        else
          Builtins.y2milestone(
            "Removing port %1 mentioned in port ranges %2",
            port_number,
            list_of_ranges
          )
        end
      end

      list_of_ranges = Builtins.toset(list_of_ranges)
      # maximal count of steps
      max_loops = 5000

      # Joining port ranges together
      # this is a bit dangerous!
      Builtins.y2milestone("Joining list of ranges %1", list_of_ranges)
      while Ops.greater_than(max_loops, 0)
        # if something goes wrong
        max_loops = Ops.subtract(max_loops, 1)

        any_change_during_this_loop = false

        try_all_these_ranges = deep_copy(list_of_ranges)
        Builtins.foreach(try_all_these_ranges) do |port_range|
          if !IsValidPortRange(port_range)
            warning = Builtins.sformat(
              "Wrong port-range definition %1, cannot join",
              port_range
            )
            Builtins.y2warning(warning) if ReportOnlyOnce(warning)
            next
          end
          min_pr = Builtins.tointeger(
            Builtins.regexpsub(port_range, "^([0123456789]+):.*$", "\\1")
          )
          max_pr = Builtins.tointeger(
            Builtins.regexpsub(port_range, "^.*:([0123456789]+)$", "\\1")
          )
          if min_pr.nil? || max_pr.nil?
            Builtins.y2error("Not a port range %1", port_range)
            next
          end
          # try to join it with another port ranges
          # -->
          Builtins.foreach(try_all_these_ranges) do |try_this_pr|
            # Exact match means the same port range
            next if try_this_pr == port_range
            this_min = Builtins.regexpsub(
              try_this_pr,
              "^([0123456789]+):.*$",
              "\\1"
            )
            this_max = Builtins.regexpsub(
              try_this_pr,
              "^.*:([0123456789]+)$",
              "\\1"
            )
            if this_min.nil? || this_max.nil?
              Builtins.y2error(
                "Wrong port range %1, %2 > %3",
                port_range,
                this_min,
                this_max
              )
              # skip it
              next
            end
            this_min_pr = Builtins.tointeger(this_min)
            this_max_pr = Builtins.tointeger(this_max)
            # // wrong definition of the port range
            if Ops.less_than(this_min_pr, 1) ||
                Ops.greater_than(this_max_pr, @max_port_number)
              warning = Builtins.sformat(
                "Wrong port-range definition %1, cannot join",
                port_range
              )
              Builtins.y2warning(warning) if ReportOnlyOnce(warning)
              # skip it
              next
            end
            # If new port range should be created
            new_min = nil
            new_max = nil
            # the second one is inside the first one
            if Ops.less_or_equal(min_pr, this_min_pr) &&
                Ops.greater_or_equal(max_pr, this_max_pr)
              # take min_pr & max_pr
              any_change_during_this_loop = true
              new_min = min_pr
              new_max = max_pr
              # the fist one is inside the second one
            elsif Ops.greater_or_equal(min_pr, this_min_pr) &&
                Ops.less_or_equal(max_pr, this_max_pr)
              # take this_min_pr & this_max_pr
              any_change_during_this_loop = true
              new_min = this_min_pr
              new_max = this_max_pr
              # the fist one partly covers the second one (by its right side)
            elsif Ops.less_or_equal(min_pr, this_min_pr) &&
                Ops.greater_or_equal(max_pr, this_min_pr)
              # take min_pr & this_max_pr
              any_change_during_this_loop = true
              new_min = min_pr
              new_max = this_max_pr
              # the second one partly covers the first one (by its left side)
            elsif Ops.greater_or_equal(min_pr, this_min_pr) &&
                Ops.less_or_equal(max_pr, this_max_pr)
              # take this_min_pr & max_pr
              any_change_during_this_loop = true
              new_min = this_min_pr
              new_max = max_pr
              # the first one has the second one just next on the right
            elsif Ops.add(max_pr, 1) == this_min_pr
              # take min_pr & this_max_pr
              any_change_during_this_loop = true
              new_min = min_pr
              new_max = this_max_pr
              # the first one has the second one just next on the left side
            elsif Ops.subtract(min_pr, 1) == this_max_pr
              # take this_min_pr & max_pr
              any_change_during_this_loop = true
              new_min = this_min_pr
              new_max = max_pr
            end
            if any_change_during_this_loop && !new_min.nil? && !new_max.nil?
              new_port_range = CreateNewPortRange(new_min, new_max)
              Builtins.y2milestone(
                "Joining %1 and %2 into %3",
                port_range,
                try_this_pr,
                new_port_range
              )
              # Remove old port ranges
              list_of_ranges = Builtins.filter(list_of_ranges) do |filter_pr|
                filter_pr != port_range && filter_pr != try_this_pr
              end
              # Create a new one
              list_of_ranges = Builtins.add(list_of_ranges, new_port_range)
            end
          end
          # <--

          # renew list of current port ranges, they have changed
          raise Break if any_change_during_this_loop
        end

        break if !any_change_during_this_loop
      end
      Builtins.y2milestone("Result of joining: %1", list_of_ranges)

      new_list = Convert.convert(
        Builtins.union(new_list, list_of_ranges),
        from: "list",
        to:   "list <string>"
      )

      deep_copy(new_list)
    end

    publish variable: :max_port_number, type: "integer"
    publish function: :IsPortRange, type: "boolean (string)"
    publish function: :IsValidPortRange, type: "boolean (string)"
    publish function: :PortIsInPortranges, type: "boolean (string, list <string>)"
    publish function: :DividePortsAndPortRanges, type: "map <string, list <string>> (list <string>, boolean)"
    publish function: :CreateNewPortRange, type: "string (integer, integer)"
    publish function: :RemovePortFromPortRanges, type: "list <string> (integer, list <string>)"
    publish function: :FlattenServices, type: "list <string> (list <string>, string)"
  end

  PortRanges = PortRangesClass.new
  PortRanges.main
end
