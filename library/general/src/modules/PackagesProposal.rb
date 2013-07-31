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
# File:	PackagesProposal.ycp
# Package:	Packages installation
# Summary:	API for selecting or de-selecting packages for installation
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# $Id$
require "yast"

module Yast
  class PackagesProposalClass < Module
    def main
      textdomain "base"

      #
      # **Structure:**
      #
      #     $[
      #          "unique_ID" : $[
      #              `package : [ "list", "of", "packages", "to", "install" ],
      #              `pattern : [ "list", "of", "patterns", "to", "install" ],
      #          ]
      #      ]
      @resolvables_to_install = {}

      # List of currently supported types of resolvables
      @supported_resolvables = [:package, :pattern]
    end

    # Resets all resolvables to install. Use carefully.
    def ResetAll
      if @resolvables_to_install != {}
        Builtins.y2warning("Reseting all PackagesProposal items")
      else
        Builtins.y2milestone("Reseting all PackagesProposal items")
      end

      @resolvables_to_install = {}

      nil
    end

    # Returns list of resolvables currently supported by this module.
    #
    # @example GetSupportedResolvables() -> [`package, `pattern, ... ]
    #
    # @return [Array<Symbol>] of resolvables
    def GetSupportedResolvables
      deep_copy(@supported_resolvables)
    end

    def IsSupportedResolvableType(type)
      if type == nil
        Builtins.y2error("Wrong type: %1", type)
        return false
      end

      Builtins.contains(@supported_resolvables, type)
    end

    # Checks the currently created data structure and creates
    # missing keys if needed.
    #
    # @param [String] unique_ID
    # @param [Symbol] type
    def CreateEmptyStructureIfMissing(unique_ID, type)
      if !Builtins.haskey(@resolvables_to_install, unique_ID)
        Builtins.y2debug(
          "Creating '%1' key in resolvables_to_install",
          unique_ID
        )
        Ops.set(@resolvables_to_install, unique_ID, {})
      end

      if !Builtins.haskey(Ops.get(@resolvables_to_install, unique_ID, {}), type)
        Builtins.y2debug(
          "Creating '%1' key in resolvables_to_install[%2]",
          type,
          unique_ID
        )
        Ops.set(@resolvables_to_install, [unique_ID, type], [])
      end

      nil
    end

    # Checks parameters for global functions
    #
    # @param [String] unique_ID
    # @param [Symbol] type
    # @return [Boolean] if parameters are correct
    def CheckParams(unique_ID, type)
      if unique_ID == nil || unique_ID == ""
        Builtins.y2error("Unique ID cannot be: %1", unique_ID)
        return false
      end

      if !IsSupportedResolvableType(type)
        Builtins.y2error(
          "Not a supported type: %1, supported are only: %2",
          type,
          @supported_resolvables
        )
        return false
      end

      true
    end

    # Adds list of resolvables to pool that is then used by software proposal
    # to propose a selection of resolvables to install.
    #
    # @param [String] unique_ID
    # @param symbol resolvable type
    # @param list <string> of resolvables to add for installation
    # @return [Boolean] whether successful
    #
    # @example
    #  AddResolvables ("y2_kdump", `package, ["yast2-kdump", "kdump"]) -> true
    #  // `not_supported is definitely not a supported resolvable
    #  AddResolvables ("test", `not_supported, ["bash"]) -> false
    #
    # @see #supported_resolvables
    # @see #RemoveResolvables()
    def AddResolvables(unique_ID, type, resolvables)
      resolvables = deep_copy(resolvables)
      return false if !CheckParams(unique_ID, type)

      CreateEmptyStructureIfMissing(unique_ID, type)

      if resolvables == nil
        Builtins.y2warning("Changing resolvables %1 to empty list", resolvables)
        resolvables = []
      end

      Builtins.y2milestone(
        "Adding resolvables %1 type %2 for %3",
        resolvables,
        type,
        unique_ID
      )
      Ops.set(
        @resolvables_to_install,
        [unique_ID, type],
        Convert.convert(
          Builtins.union(
            Ops.get(@resolvables_to_install, [unique_ID, type], []),
            resolvables
          ),
          :from => "list",
          :to   => "list <string>"
        )
      )

      true
    end

    # Replaces the current resolvables with new ones. Similar to AddResolvables()
    # but it replaces the list of resolvables instead of adding them to the pool.
    # It always replaces only the part that is identified by the unique_ID.
    #
    # @param [String] unique_ID
    # @param symbol resolvable type
    # @param list <string> of resolvables to add for installation
    # @return [Boolean] whether successful
    def SetResolvables(unique_ID, type, resolvables)
      resolvables = deep_copy(resolvables)
      return false if !CheckParams(unique_ID, type)

      CreateEmptyStructureIfMissing(unique_ID, type)

      if resolvables == nil
        Builtins.y2warning("Changing resolvables %1 to empty list", resolvables)
        resolvables = []
      end

      Builtins.y2milestone(
        "Adjusting resolvables %1 type %2 for %3",
        resolvables,
        type,
        unique_ID
      )
      Ops.set(@resolvables_to_install, [unique_ID, type], resolvables)

      true
    end

    # Removes list of packages from pool that is then used by software proposal
    # to propose a selection of resolvables to install.
    #
    # @param [String] unique_ID
    # @param symbol resolvable type
    # @param list <string> of resolvables to remove from list selected for installation
    # @return [Boolean] whether successful
    #
    # @example
    #  RemoveResolvables ("y2_kdump", `package, ["kdump"]) -> true
    #
    # @see #supported_resolvables
    # @see #AddResolvables()
    def RemoveResolvables(unique_ID, type, resolvables)
      resolvables = deep_copy(resolvables)
      return false if !CheckParams(unique_ID, type)

      CreateEmptyStructureIfMissing(unique_ID, type)

      if resolvables == nil
        Builtins.y2warning("Changing resolvables %1 to empty list", resolvables)
        resolvables = []
      end

      Builtins.y2milestone(
        "Removing resolvables %1 type %2 for %3",
        resolvables,
        type,
        unique_ID
      )
      Ops.set(
        @resolvables_to_install,
        [unique_ID, type],
        Builtins.filter(Ops.get(@resolvables_to_install, [unique_ID, type], [])) do |one_resolvable|
          !Builtins.contains(resolvables, one_resolvable)
        end
      )
      Builtins.y2milestone(
        "Resolvables left: %1",
        Ops.get(@resolvables_to_install, [unique_ID, type], [])
      )

      true
    end

    # Returns all resolvables selected for installation.
    #
    # @param [String] unique_ID
    # @param symbol resolvable type
    # @return [Array<String>] of resolvables
    #
    # @example
    #   GetResolvables ("y2_kdump", `package) -> ["yast2-kdump", "kdump"]
    def GetResolvables(unique_ID, type)
      return nil if !CheckParams(unique_ID, type)

      Ops.get(@resolvables_to_install, [unique_ID, type], [])
    end

    # Returns list of selected resolvables of a given type
    #
    # @param symbol resolvable type
    # @return [Array<String>] list of resolvables
    #
    # @example
    #   GetAllResolvables (`package) -> ["list", "of", "packages"]
    #   GetAllResolvables (`pattern) -> ["list", "of", "patterns"]
    #   // not a supported resolvable type
    #   GetAllResolvables (`unknown) -> nil
    #
    # @see #supported_resolvables
    def GetAllResolvables(type)
      if !IsSupportedResolvableType(type)
        Builtins.y2error(
          "Not a supported type: %1, supported are only: %2",
          type,
          @supported_resolvables
        )
        return nil
      end

      ret = []

      Builtins.foreach(@resolvables_to_install) do |unique_ID, resolvables|
        if Builtins.haskey(resolvables, type)
          ret = Builtins.sort(
            Convert.convert(
              Builtins.union(ret, Ops.get(resolvables, type, [])),
              :from => "list",
              :to   => "list <string>"
            )
          )
        end
      end

      deep_copy(ret)
    end

    # Returns all selected resolvables for all supported types
    #
    # @return [Hash{Symbol => Array<String>}] map of resolvables
    #
    # **Structure:**
    #
    #     $[
    #        `resolvable_type : [ "list", "of", "resolvables" ],
    #        `another_type    : [ "list", "of", "resolvables" ],
    #      ]
    #
    # @example
    # // No resolvables selected
    # GetAllResolvablesForAllTypes() -> $[]
    # // Only patterns selected
    # GetAllResolvablesForAllTypes() -> $[`pattern : ["some", "patterns"]]
    # // Also packages selected
    # GetAllResolvablesForAllTypes() -> $[
    #   `pattern : ["some", "patterns"],
    #   `package : ["some", "packages"],
    # ]
    def GetAllResolvablesForAllTypes
      ret = {}
      resolvables = []

      Builtins.foreach(GetSupportedResolvables()) do |one_type|
        resolvables = GetAllResolvables(one_type)
        if resolvables != nil && resolvables != []
          Ops.set(ret, one_type, resolvables)
        end
      end

      deep_copy(ret)
    end

    # Return whether a unique ID is already in use.
    #
    # @param [String] unique_ID to check
    # @return [Boolean] whether the ID is not in use yet
    def IsUniqueID(unique_ID)
      if unique_ID == nil || unique_ID == ""
        Builtins.y2error("Unique ID cannot be: %1", unique_ID)
        return nil
      end

      !Builtins.haskey(@resolvables_to_install, unique_ID)
    end

    publish :function => :ResetAll, :type => "void ()"
    publish :function => :GetSupportedResolvables, :type => "list <symbol> ()"
    publish :function => :AddResolvables, :type => "boolean (string, symbol, list <string>)"
    publish :function => :SetResolvables, :type => "boolean (string, symbol, list <string>)"
    publish :function => :RemoveResolvables, :type => "boolean (string, symbol, list <string>)"
    publish :function => :GetResolvables, :type => "list <string> (string, symbol)"
    publish :function => :GetAllResolvables, :type => "list <string> (symbol)"
    publish :function => :GetAllResolvablesForAllTypes, :type => "map <symbol, list <string>> ()"
    publish :function => :IsUniqueID, :type => "boolean (string)"
  end

  PackagesProposal = PackagesProposalClass.new
  PackagesProposal.main
end
