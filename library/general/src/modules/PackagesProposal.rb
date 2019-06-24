# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2002 - 2012 Novell, Inc.
# Copyright (c) 2016 SUSE LLC
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

require "yast"

module Yast
  # API for selecting or de-selecting packages or patterns for installation.
  # It stores two separate lists, one for required resolvables and the other one
  # for optional resolvables. The optional resolvables can be deselected by user
  # manually and the installation proposal will not complain that they are missing.
  class PackagesProposalClass < Module
    include Yast::Logger

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
      # the same as above but the resolvables are considered optional
      @opt_resolvables_to_install = {}

      # List of currently supported types of resolvables
      @supported_resolvables = [:package, :pattern]
    end

    # Resets all resolvables to install (both required and optional). Use carefully.
    def ResetAll
      log.info("Resetting all PackagesProposal items")

      @resolvables_to_install.clear
      @opt_resolvables_to_install.clear

      nil
    end

    # Returns list of resolvables currently supported by this module.
    #
    # @example GetSupportedResolvables() -> [`package, `pattern, ... ]
    #
    # @return [Array<Symbol>] of resolvables
    def GetSupportedResolvables
      @supported_resolvables
    end

    def IsSupportedResolvableType(type)
      log.warn("Type cannot be nil") if type.nil?

      @supported_resolvables.include?(type)
    end

    # Checks parameters for global functions
    #
    # @param [String] unique_id
    # @param [Symbol] type
    # @return [Boolean] if parameters are correct
    def CheckParams(unique_id, type)
      if unique_id.nil? || unique_id == ""
        log.error("Unique ID cannot be: #{unique_id.inspect}")
        return false
      end

      if !IsSupportedResolvableType(type)
        log.error("Not a supported type: #{type}")
        return false
      end

      true
    end

    # Adds list of resolvables to pool that is then used by software proposal
    # to propose a selection of resolvables to install.
    #
    # @param [String] unique_id
    # @param symbol resolvable type
    # @param list <string> of resolvables to add for installation
    # @param [Boolean] optional True for optional list, false (the default) for
    #   the required list
    # @return [Boolean] whether successful
    #
    # @example
    #  AddResolvables ("y2_kdump", `package, ["yast2-kdump", "kdump"]) -> true
    #  // `not_supported is definitely not a supported resolvable
    #  AddResolvables ("test", `not_supported, ["bash"]) -> false
    #
    # @see #supported_resolvables
    # @see #RemoveResolvables()
    def AddResolvables(unique_id, type, resolvables, optional: false)
      resolvables = deep_copy(resolvables)
      return false if !CheckParams(unique_id, type)

      if resolvables.nil?
        log.info("Using empty list instead of nil")
        resolvables = []
      end

      log.info("Adding #{log_label(optional)} #{resolvables} of type #{type} for #{unique_id}")

      current_resolvables = data_for(unique_id, type, optional: optional)
      current_resolvables.concat(resolvables)

      true
    end

    # Replaces the current resolvables with new ones. Similar to AddResolvables()
    # but it replaces the list of resolvables instead of adding them to the pool.
    # It always replaces only the part that is identified by the unique_id.
    #
    # @param [String] unique_id the unique identificator
    # @param [Symbol] type resolvable type
    # @param [Array<String>] resolvables list of resolvables to add for installation
    # @param [Boolean] optional True for optional list, false (the default) for
    #   the required list
    # @return [Boolean] whether successful
    def SetResolvables(unique_id, type, resolvables, optional: false)
      resolvables = deep_copy(resolvables)
      return false if !CheckParams(unique_id, type)

      if resolvables.nil?
        log.warn("Using empty list instead of nil")
        resolvables = []
      end

      log.info("Setting #{log_label(optional)} #{resolvables} of type #{type} for #{unique_id}")

      current_resolvables = data_for(unique_id, type, optional: optional)
      current_resolvables.replace(resolvables)

      true
    end

    # Removes list of packages from pool that is then used by software proposal
    # to propose a selection of resolvables to install.
    #
    # @param [String] unique_id the unique identificator
    # @param [Symbol] type resolvable type
    # @param [Array<String>] resolvables list of resolvables to add for installation
    # @param [Boolean] optional True for optional list, false (the default) for
    #   the required list
    # @return [Boolean] whether successful
    #
    # @example
    #  RemoveResolvables ("y2_kdump", `package, ["kdump"]) -> true
    #
    # @see #supported_resolvables
    # @see #AddResolvables()
    def RemoveResolvables(unique_id, type, resolvables, optional: false)
      resolvables = deep_copy(resolvables)
      return false if !CheckParams(unique_id, type)

      if resolvables.nil?
        log.warn("Using empty list instead of nil")
        resolvables = []
      end

      log.info("Removing #{log_label(optional)} #{resolvables} type #{type} for #{unique_id}")

      current_resolvables = data_for(unique_id, type, optional: optional)
      current_resolvables.reject! { |r| resolvables.include?(r) }

      log.info("#{log_label(optional)} left: #{current_resolvables.inspect}")

      true
    end

    # Returns all resolvables selected for installation.
    #
    # @param [String] unique_id the unique identificator
    # @param [Symbol] type resolvable type
    # @param [Boolean] optional True for optional list, false (the default) for
    #   the required list

    # @return [Array<String>] of resolvables
    #
    # @example
    #   GetResolvables ("y2_kdump", `package) -> ["yast2-kdump", "kdump"]
    def GetResolvables(unique_id, type, optional: false)
      return nil if !CheckParams(unique_id, type)

      data(optional).fetch(unique_id, {}).fetch(type, [])
    end

    # Returns list of selected resolvables of a given type
    #
    # @param [Symbol] type resolvable type
    # @param [Boolean] optional True for optional list, false (the default) for
    #   the required list
    # @return [Array<String>] list of resolvables
    #
    # @example
    #   GetAllResolvables (`package) -> ["list", "of", "packages"]
    #   GetAllResolvables (`pattern) -> ["list", "of", "patterns"]
    #   // not a supported resolvable type
    #   GetAllResolvables (`unknown) -> nil
    #
    # @see #supported_resolvables
    def GetAllResolvables(type, optional: false)
      if !IsSupportedResolvableType(type)
        log.error("Not a supported type: #{type}, supported are only: #{@supported_resolvables}")
        return nil
      end

      ret = []

      data(optional).each_value do |resolvables|
        ret.concat(resolvables[type]) if resolvables.key?(type)
      end

      # sort the result and remove the duplicates
      ret.sort!
      ret.uniq!

      ret
    end

    # Returns all selected resolvables for all supported types
    #
    # @param [Boolean] optional True for optional list, false (the default) for
    #   the required list
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
    def GetAllResolvablesForAllTypes(optional: false)
      ret = {}

      GetSupportedResolvables().each do |one_type|
        resolvables = GetAllResolvables(one_type, optional: optional)
        ret[one_type] = resolvables if !resolvables.nil? && !resolvables.empty?
      end

      ret
    end

    # Returns true/false indicating whether the ID is already in use.
    #
    # @param [String] unique_id the unique identificator to check
    # @return [Boolean] true if the ID is not used, false otherwise
    def IsUniqueID(unique_id)
      if unique_id.nil? || unique_id == ""
        log.error("Unique ID cannot be #{unique_id.inspect}")
        return nil
      end

      !@resolvables_to_install.key?(unique_id) && !@opt_resolvables_to_install.key?(unique_id)
    end

    publish function: :ResetAll, type: "void ()"
    publish function: :GetSupportedResolvables, type: "list <symbol> ()"
    publish function: :AddResolvables, type: "boolean (string, symbol, list <string>)"
    publish function: :SetResolvables, type: "boolean (string, symbol, list <string>)"
    publish function: :RemoveResolvables, type: "boolean (string, symbol, list <string>)"
    publish function: :GetResolvables, type: "list <string> (string, symbol)"
    publish function: :GetAllResolvables, type: "list <string> (symbol)"
    publish function: :GetAllResolvablesForAllTypes, type: "map <symbol, list <string>> ()"
    publish function: :IsUniqueID, type: "boolean (string)"

  private

    # Return the required or the optional resolvable list.
    # @param [Boolean] optional true for optional resolvables, false for
    #   the required resolvables
    # @return [Hash] the stored resolvables
    def data(optional)
      optional ? @opt_resolvables_to_install : @resolvables_to_install
    end

    # Build a label for logging resolvable kind
    # @param [Boolean] optional true for optinal resolvables, false for required ones
    # @return [String] description of the resolvables
    def log_label(optional)
      optional ? "optional resolvables" : "resolvables"
    end

    # Returns the resolvable list for the requested ID, resolvable type and kind
    # (required/optinal). If the list does not exit yet then a new empty list is created.
    #
    # @param [String] unique_id
    # @param [Symbol] type
    # @param [Boolean] optional True for optional list, false (the default) for
    #   the required list
    # @return [Array<String>] the stored resolvables list
    def data_for(unique_id, type, optional: false)
      if !data(optional).key?(unique_id)
        log.debug("Creating #{unique_id.inspect} ID")
        data(optional)[unique_id] = {}
      end

      if !data(optional)[unique_id].key?(type)
        log.debug("Creating '#{type}' key for #{unique_id.inspect} ID")
        data(optional)[unique_id][type] = []
      end

      data(optional)[unique_id][type]
    end
  end

  PackagesProposal = PackagesProposalClass.new
  PackagesProposal.main
end
