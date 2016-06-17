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
# File:        modules/ValueBrowser.ycp
# Package:     YaST2 base package
# Summary:     Useful tool for viewing any variable contents.
# Authors:     Martin Vidner <mvidner@suse.cz>
#		Dan Vesely?
# Flags:	Unstable
#
# $Id$
require "yast"

module Yast
  class ValueBrowserClass < Module
    def main
      Yast.import "UI"

      textdomain "base"

      Yast.import "Label"
    end

    # Helper function that replaces all ocurences of "\n" with "\\n", so items are not multiline :-)
    # @param [String] s string to escape
    # @return [String] escaped string
    def escapestring(s)
      Builtins.mergestring(Builtins.splitstring(s, "\n"), "\\n")
    end

    # Shows tree with contents of variable. This function does the job. Heavy recursion...
    # @param [Object] variable variable to show.
    # @param [String] indent string that is printed before each output.
    def FormatSimpleType(variable, indent)
      variable = deep_copy(variable)
      if Ops.is_void?(variable)
        Builtins.sformat("%2%1 (void)", variable, indent)
      elsif Ops.is_boolean?(variable)
        Builtins.sformat("%2%1 (boolean)", variable, indent)
      elsif Ops.is_integer?(variable)
        Builtins.sformat(
          "%2%1, %3 (integer)",
          variable,
          indent,
          Builtins.tohexstring(Convert.to_integer(variable))
        )
      elsif Ops.is_float?(variable)
        Builtins.sformat("%2%1 (float)", variable, indent)
      elsif Ops.is_string?(variable)
        return Builtins.sformat(
          "%2%1 (string)",
          escapestring(Convert.to_string(variable)),
          indent
        )
      elsif Ops.is_locale?(variable)
        Builtins.sformat("%2%1 (locale)", variable, indent)
      elsif Ops.is_byteblock?(variable)
        Builtins.sformat("%2%1 (byteblock)", variable, indent)
      elsif Ops.is_symbol?(variable)
        Builtins.sformat("%2%1 (symbol)", variable, indent)
      elsif Ops.is_path?(variable)
        Builtins.sformat("%2%1 (path)", variable, indent)
      else
        nil
      end
    end

    # Creates tree with contents of variable. This function creates the tree items and
    # returns them as term. This offers using the generated output in your behavior,
    # such as data-structure browser with editor. Heavy recursion...
    #
    # @param [Object] variable variable to show.
    # @param [String] indent string that is printed before each output.
    def BrowseTreeHelper(variable, indent)
      variable = deep_copy(variable)
      simple = FormatSimpleType(variable, indent)

      return Item(simple) if !simple.nil?

      if Ops.is_list?(variable)
        items = []
        Builtins.foreach(Convert.to_list(variable)) do |i|
          items = Builtins.add(items, BrowseTreeHelper(i, ""))
        end
        return Item(Builtins.sformat("%1 (list)", indent), items)
      elsif Ops.is_map?(variable)
        items = []
        Builtins.foreach(Convert.to_map(variable)) do |k, v|
          items = Builtins.add(
            items,
            BrowseTreeHelper(v, Builtins.sformat("%1: ", k))
          )
        end
        return Item(Builtins.sformat("%1 (map)", indent), items)
      elsif Ops.is_term?(variable)
        tvariable = Convert.to_term(variable)
        items = []
        len = Builtins.size(tvariable)
        i = 0
        while Ops.less_than(i, len)
          items = Builtins.add(
            items,
            BrowseTreeHelper(Ops.get(tvariable, i), "")
          )
          i = Ops.add(i, 1)
        end
        return Item(
          Builtins.sformat("%1%2 (term)", indent, Builtins.symbolof(tvariable)),
          items
        )
      end

      nil
    end

    # Shows tree with contents of variable.
    #
    # @example
    #  map a = $[
    #     "first" : 35,
    #     "second" : [ 1, 2, 3, 4, 5],
    #     "third" : $[ "a" : 15, `b: `VBox () ]
    #    ];
    #  ValueBrowser::BrowseTree (a);
    #
    # @param [Object] variable variable to show.
    def BrowseTree(variable)
      variable = deep_copy(variable)
      items = BrowseTreeHelper(variable, "")
      UI.OpenDialog(
        Opt(:defaultsize),
        VBox(
          # translators: Tree header
          Tree(Opt(:hstretch, :vstretch), _("&Variable"), [items]),
          ButtonBox(
            PushButton(Id(:ok), Opt(:okButton, :key_F10), Label.OKButton)
          )
        )
      )
      UI.UserInput
      UI.CloseDialog

      nil
    end

    # Write contents of variable to log file. This function does the job.
    # Heavy recursion...
    # @param [Object] variable variable to show.
    # @param [String] indent string that is printed before each output.
    def DebugBrowseHelper(variable, indent)
      variable = deep_copy(variable)
      simple = FormatSimpleType(variable, indent)
      if !simple.nil?
        Builtins.y2debug("%1", simple)
      elsif Ops.is_list?(variable)
        Builtins.foreach(Convert.to_list(variable)) do |i|
          DebugBrowseHelper(i, Ops.add(indent, "  "))
        end
      elsif Ops.is_map?(variable)
        Builtins.foreach(Convert.to_map(variable)) do |k, v|
          Builtins.y2debug("%2%1 (map key)", k, indent)
          DebugBrowseHelper(v, Builtins.sformat("  %1", indent))
        end
      elsif Ops.is_term?(variable)
        tvariable = Convert.to_term(variable)
        items = []
        len = Builtins.size(tvariable)
        i = 0
        Builtins.y2debug("%1%2 (term)", indent, Builtins.symbolof(tvariable))
        while Ops.less_than(i, len)
          items = Builtins.add(
            items,
            DebugBrowseHelper(Ops.get(tvariable, i), "")
          )
          i = Ops.add(i, 1)
        end
      end

      nil
    end

    # Write contents of variable to log file.
    # @param [Object] variable variable to show.
    def DebugBrowse(variable)
      variable = deep_copy(variable)
      DebugBrowseHelper(variable, "")

      nil
    end

    publish function: :BrowseTreeHelper, type: "term (any, string)"
    publish function: :BrowseTree, type: "void (any)"
    publish function: :DebugBrowseHelper, type: "void (any, string)"
    publish function: :DebugBrowse, type: "void (any)"
  end

  ValueBrowser = ValueBrowserClass.new
  ValueBrowser.main
end
