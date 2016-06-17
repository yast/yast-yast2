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
# File:	modules/Sequencer.ycp
# Module:	yast2
# Summary:	Wizard Sequencer
# Authors:	Michal Svec <msvec@suse.cz>
# Flags:	Stable
#
# $Id$
#
# This is an implementation of the wizard sequencer, the tool for
# processing workflows of dialogs.
# <br>
# All errors are reported to y2log, so if anything is unfunctional
# look to the y2log.
require "yast"

module Yast
  class SequencerClass < Module
    def main
      textdomain "base"

      @docheck = true
    end

    # Test (run) all dialogs in the aliases map
    # @param [Hash] aliases the map of aliases
    # @return returned values of tested dialogs
    # @see WS documentation for the format of aliases map
    def WS_testall(aliases)
      aliases = deep_copy(aliases)
      Builtins.maplist(aliases) { |_id, func| Builtins.eval(func) }
    end

    # Check correct types in maps and alias presence for sequence.
    # @param [Hash] aliases the map of aliases
    # @param [Hash] sequence the sequence of dialogs
    # @return check passed?
    def WS_check(aliases, sequence)
      aliases = deep_copy(aliases)
      sequence = deep_copy(sequence)
      ret = []

      # check if aliases is not a nil
      if aliases.nil?
        Builtins.y2error(2, "sequencer check: aliases is nil")
        return false
      end

      # check if sequence is not a nil
      if sequence.nil?
        Builtins.y2error(2, "sequencer check: sequence is nil")
        return false
      end

      # check if ws_start is in aliases
      if Ops.get(aliases, "ws_start")
        Builtins.y2error(2, "sequencer check: ws_start cannot be an alias name")
        ret = Builtins.add(ret, false)
      else
        ret = Builtins.add(ret, true)
      end

      # check aliases map types
      ret0 = Builtins.maplist(aliases) do |key, val|
        if !Ops.is_string?(key)
          Builtins.y2error(2, "sequencer check: not a string: %1", key)
          next false
        elsif Ops.is_list?(val)
          if Ops.less_than(Builtins.size(Convert.to_list(val)), 2)
            Builtins.y2error(
              2,
              "sequencer check: list size too small: %1 (key: %2)",
              Builtins.size(Convert.to_list(val)),
              key
            )
            next false
          # FIXME: use function pointers
          #             else if (!is(select((list) val, 0, nil), term)) {
          #                 y2error(2, "sequencer check: not a term: %1", select((list) val, 0, nil));
          #                 return false;
          #             }
          elsif !Ops.is_boolean?(Ops.get(Convert.to_list(val), 1))
            Builtins.y2error(
              2,
              "sequencer check: not a boolean: %1",
              Ops.get(Convert.to_list(val), 1)
            )
            next false
          else
            next true
          end
        else
          # FIXME: use function pointers
          #         else if (!is(val, term)) {
          #             y2error(2, "sequencer check: not a term: %1", val);
          #             return false;
          #         }
          next true
        end
      end
      ret = Builtins.flatten([ret, ret0])

      # check if ws_start is in sequence
      if Ops.get(sequence, "ws_start").nil?
        Builtins.y2error(2, "sequencer check: ws_start needs to be defined")
        ret = Builtins.add(ret, false)
      else
        ret = Builtins.add(ret, true)
      end

      # check all aliases in sequence
      ret0 = Builtins.maplist(sequence) do |key, val|
        if key == "ws_start"
          next true unless !Ops.is_symbol?(val) && Ops.get(aliases, val).nil?

          Builtins.y2error(2, "sequencer check: alias not found: %1", val)
          next false
        elsif Ops.get(aliases, key).nil?
          Builtins.y2error(2, "sequencer check: alias not found: %1", key)
          next false
        elsif !Ops.is_map?(val)
          Builtins.y2error(2, "sequencer check: not a map: %1 %2", key, val)
          next false
        else
          ret1 = Builtins.maplist(Convert.to_map(val)) do |k, v|
            if !Ops.is_symbol?(k)
              Builtins.y2error(2, "sequencer check: not a symbol: %1", k)
              next false
            elsif !Ops.is_symbol?(v) && Ops.get(aliases, v).nil?
              Builtins.y2error(2, "sequencer check: alias not found: %1", v)
              next false
            else
              next true
            end
          end
          next ret1.all? { |v| v }
        end
      end
      ret = Builtins.flatten([ret, ret0])

      # check that all aliases are used
      ret0 = Builtins.maplist(aliases) do |key, _val|
        if !Builtins.haskey(sequence, key)
          Builtins.y2warning(2, "sequencer check: alias not used: %1", key)
          # return false;
        end
        true
      end
      ret = Builtins.flatten([ret, ret0])

      ret.all? { |v| v }
    end

    # Report error and return nil
    # @param [String] error the error message text
    # @return always nil
    # @see bug #6474
    def WS_error(error)
      Builtins.y2error(1, "sequencer: %1", error)
      nil
    end

    # Find an aliases in the aliases map
    # @param [Hash] aliases map of aliases
    # @param [String] alias given alias
    # @return [Yast::Term] belonging to the given alias or nil, if error
    def WS_alias(aliases, alias_)
      aliases = deep_copy(aliases)
      found = Ops.get(aliases, alias_)
      if found.nil?
        return WS_error(Builtins.sformat("Alias not found: %1", alias_))
      end
      if Ops.is_list?(found)
        if Ops.less_or_equal(Builtins.size(Convert.to_list(found)), 0)
          return WS_error(Builtins.sformat("Invalid alias: %1", found))
        end
        found = Ops.get(Convert.to_list(found), 0)
      end
      if found.nil?
        return WS_error(Builtins.sformat("Invalid alias: %1", found))
      end

      deep_copy(found)
    end

    # Decide if an alias is special
    # @param [Hash] aliases map of aliases
    # @param [String] alias given alias
    # @return true if the given alias is special or nil, if not found
    def WS_special(aliases, alias_)
      aliases = deep_copy(aliases)
      found = Ops.get(aliases, alias_)
      if found.nil?
        return Convert.to_boolean(
          WS_error(Builtins.sformat("Alias not found: %1", alias_))
        )
      end
      ret = false
      if Ops.is_list?(found)
        if Ops.greater_than(Builtins.size(Convert.to_list(found)), 1)
          ret = Ops.get_boolean(Convert.to_list(found), 1)
        end
      end
      ret
    end

    # Find a next item in the sequence
    # @param [Hash] sequence sequence of dialogs
    # @param [String] current current dialog
    # @param [Symbol] ret returned value (determines the next dialog)
    # @return next dialog (symbol), WS action (string) or nil, if error (current or next not found)
    def WS_next(sequence, current, ret)
      sequence = deep_copy(sequence)
      found = Ops.get_map(sequence, current)
      if found.nil?
        return WS_error(Builtins.sformat("Current not found: %1", current))
      end
      # string|symbol next
      next_ = Ops.get(found, ret)
      if next_.nil?
        return WS_error(Builtins.sformat("Symbol not found: %1", ret))
      end
      deep_copy(next_)
    end

    # Run a function from the aliases map
    # @param [Hash] aliases map of aliases
    # @param [String] id function to run
    # @return returned value from function or nil, if function is nil or returned something else than symbol
    def WS_run(aliases, id)
      aliases = deep_copy(aliases)
      Builtins.y2debug("Running: %1", id)

      function = WS_alias(aliases, id)
      if function.nil?
        return Convert.to_symbol(WS_error(Builtins.sformat("Bad id: %1", id)))
      end

      ret = Builtins.eval(function)

      if !Ops.is_symbol?(ret)
        return Convert.to_symbol(
          WS_error(Builtins.sformat("Returned value not symbol: %1", ret))
        )
      end

      Convert.to_symbol(ret)
    end

    # Push one item to the stack
    # @param [Array] stack stack of previously run dialogs
    # @param [Object] item item to be pushed
    # @return the new stack or nil, if the stack is nil
    def WS_push(stack, item)
      stack = deep_copy(stack)
      item = deep_copy(item)
      return nil if stack.nil?

      return Builtins.add(stack, item) if !Builtins.contains(stack, item)

      found = false
      newstack = Builtins.filter(stack) do |v|
        next false if found
        found = true if v == item
        true
      end

      deep_copy(newstack)
    end

    # Pop one item from the stack (remove an item and return the stack top item)
    # @param [Array] stack stack of previously run dialogsk
    # @return [ new stack, poped value ] or nil if the stack is empty or nil
    def WS_pop(stack)
      stack = deep_copy(stack)
      return nil if stack.nil?
      num = Builtins.size(stack)
      return nil if Ops.less_than(num, 2)
      newstack = Builtins.remove(stack, Ops.subtract(num, 1))
      poped = Ops.get(stack, Ops.subtract(num, 2))
      [newstack, poped]
    end

    # The Wizard Sequencer
    # @param [Hash] aliases the map of aliases
    # @param [Hash] sequence the sequence of dialogs
    # @return final symbol or nil, if error (see the y2log)
    def Run(aliases, sequence)
      aliases = deep_copy(aliases)
      sequence = deep_copy(sequence)
      # Check aliases and sequence correctness
      if @docheck && WS_check(aliases, sequence) != true
        return Convert.to_symbol(WS_error("CHECK FAILED"))
      end

      stack = []
      # string|symbol current
      current = Ops.get(sequence, "ws_start")
      if current.nil?
        return Convert.to_symbol(WS_error("Starting dialog not found"))
      end

      loop do
        if Ops.is_symbol?(current)
          Builtins.y2debug("Finished")
          return Convert.to_symbol(current)
        end

        stack = WS_push(stack, current)
        Builtins.y2debug("stack=%1", stack)
        ret = WS_run(aliases, Convert.to_string(current))

        if ret.nil? || !Ops.is_symbol?(ret)
          return Convert.to_symbol(
            WS_error(Builtins.sformat("Invalid ret: %1", ret))
          )
        elsif ret == :back
          Builtins.y2debug("Back")
          poped = []
          special = true
          loop do
            return :back if Ops.less_than(Builtins.size(stack), 2)
            poped = WS_pop(stack)
            Builtins.y2debug("poped=%1", poped)
            current = Ops.get(poped, 1)
            stack = Ops.get_list(poped, 0)
            special = WS_special(aliases, Convert.to_string(current))
            Builtins.y2debug("special=%1", special)
            break if !special
          end
        else
          Builtins.y2debug("ret=%1", ret)
          current = WS_next(
            sequence,
            Convert.to_string(current),
            Convert.to_symbol(ret)
          )
          Builtins.y2debug("current=%1", current)
          if current.nil?
            return Convert.to_symbol(
              WS_error(Builtins.sformat("Next not found: %1", current))
            )
          end
        end
      end

      # Not reached
      nil
    end

    publish variable: :docheck, type: "boolean", private: true
    publish function: :WS_testall, type: "list (map)", private: true
    publish function: :WS_check, type: "boolean (map, map)", private: true
    publish function: :WS_error, type: "any (string)", private: true
    publish function: :WS_alias, type: "any (map, string)", private: true
    publish function: :WS_special, type: "boolean (map, string)", private: true
    publish function: :WS_next, type: "any (map, string, symbol)", private: true
    publish function: :WS_run, type: "symbol (map, string)", private: true
    publish function: :WS_push, type: "list (list, any)", private: true
    publish function: :WS_pop, type: "list (list)", private: true
    publish function: :Run, type: "symbol (map, map)"
  end

  Sequencer = SequencerClass.new
  Sequencer.main
end
