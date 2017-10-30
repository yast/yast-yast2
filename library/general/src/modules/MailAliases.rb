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
# File:
#   modules/Mail.ycp
#
# Package:
#   Configuration of mail aliases
#
# Summary:
#   Data for configuration of mail aliases, input and output functions.
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#
# $Id: MailAliases.ycp 35035 2007-01-02 14:35:30Z mvidner $
#
# Representation of the configuration of mail aliases.
# Input and output routines.
# Separated from Mail.ycp because yast2-users need us.
# Virtusertable/virtual users are not included, arbitrarily.
#
require "yast"

require "cfa/aliases"

module Yast
  class MailAliasesClass < Module
    def main
      # List of maps: $[comment:, alias:, destinations:] (all are strings)
      # Except root.
      @aliases = []
      # Separated/joined with aliases by read/write/set/export
      @root_alias = ""
    end

    # Useful for autoinstall: the provided aliases will be (with
    # higher priority) merged with existing ones (presumably system defaults).
    #    global boolean merge_aliases = false;

    # ----------------------------------------------------------------

    # Separates aliases into aliases, root_alias and root_alias_comment
    def FilterRootAlias
      @root_alias = ""
      @aliases = Builtins.filter(@aliases) do |e|
        if Ops.get_string(e, "alias", "") == "root"
          @root_alias = Ops.get_string(e, "destinations", "")
          next false
        end
        true
      end

      nil
    end

    # Read the aliases table (and separate the root alias)
    # @return success?
    def ReadAliases
      @cfa_aliases = CFA::Aliases.new
      @cfa_aliases.load
      @aliases = @cfa_aliases.aliases.map do |k,v|
        {
          "comment"      => "", #not used
          "alias"        => k,
          "destinations" => v
        }
      end
      FilterRootAlias()
      true
    end

    # @param [Array<Hash>] aliases an alias table
    # @return prepend root alias data to aliases, if set
    def MergeRootAlias(aliases)
      aliases = deep_copy(aliases)
      ret = deep_copy(aliases)
      if @root_alias != ""
        ret = Builtins.prepend(
          ret,

          "alias"        => "root",
          "destinations" => @root_alias,
          "comment"      => ""

        )
      end
      deep_copy(ret)
    end

    # Part of Write.
    # @return success
    # @see #SetRootAlias
    def WriteAliases
      @cfa_aliases ||= CFA::Aliases.new
      @cfa_aliases.aliases = MergeRootAlias(@aliases)
      @cfa_aliases.save

      true
    end

    # ----------------------------------------------------------------

    # For use by the Users package.
    # Does not rely on the internal state, first calls the agent.
    # @return eg. "joe, \\root", "" if not defined
    def GetRootAlias
      return "" if !ReadAliases()
      @root_alias
    end

    # For use by the Users package.
    # Does not use the internal state, just calls the agent.
    # SuSEconfig or newaliases is NOT called!
    # (TODO: what if it is called while the main module is running?)
    # Errors are reported via Report::Error.
    # @param [String] destinations The new alias. If "", it is removed.
    # @return true on success
    def SetRootAlias(destinations)
      return false if !ReadAliases()

      @root_alias = destinations

      return false if !WriteAliases()
      true
    end

    publish variable: :aliases, type: "list <map>"
    publish variable: :root_alias, type: "string"
    publish function: :FilterRootAlias, type: "void ()"
    publish function: :ReadAliases, type: "boolean ()"
    publish function: :MergeRootAlias, type: "list <map> (list <map>)"
    publish function: :WriteAliases, type: "boolean ()"
    publish function: :GetRootAlias, type: "string ()"
    publish function: :SetRootAlias, type: "boolean (string)"
  end

  MailAliases = MailAliasesClass.new
  MailAliases.main
end
