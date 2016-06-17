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
# File:	modules/TablePopup.ycp
# Package:	Table/Popup dialogs backend
# Summary:	Routines for Table/Popup interface
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
require "yast"

module Yast
  class TablePopupClass < Module
    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "CWM"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Report"

      # variables

      # Item, that is the last selected
      # Used to decide if selected item should be moved up or down if separator
      #  clicked
      # Loss of contents is no problem
      @previous_selected_item = nil
    end

    # local functions

    # Get list of IDs of entries of the table
    # @param [Hash{String => Object}] descr map table description map
    # @return [Array] of IDs of the table
    def getIdList(descr)
      descr = deep_copy(descr)
      toEval = Convert.convert(
        Ops.get(descr, "ids"),
        from: "any",
        to:   "list (map)"
      )
      return toEval.call(descr) if !toEval.nil?
      []
    end

    # Validate table options specifyign attributesA
    # @param [Hash{String => Object}] attr a map of table attributes
    # @return [Boolean] true if validation succeeded
    def ValidateTableAttr(attr)
      attr = deep_copy(attr)
      types = {
        "add_delete_buttons" => "boolean",
        "edit_button"        => "boolean",
        "changed_column"     => "boolean",
        "up_down_buttons"    => "boolean",
        "unique_keys"        => "boolean"
      }
      ret = true
      Builtins.foreach(attr) do |k, v|
        type = Ops.get(types, k)
        if type.nil?
          Builtins.y2error("Unknown attribute %1", k)
          ret = false
        else
          ret = CWM.ValidateBasicType(v, type) && ret
        end
      end
      ret
    end

    # Validate type of entry of the option description map
    # Also checks option description maps if present
    # @param [String] key string key of the map entry
    # @param [Object] value any value of the map entry
    # @param [String] widget any name of the widget/option
    # @param [Boolean] popup boolean true if is option of a popup
    # @return [Boolean] true if validation succeeded
    def ValidateValueType(key, value, widget, popup)
      value = deep_copy(value)
      success = true
      if popup
        if key == "init"
          success = Ops.is(value, "void (any, string)")
        elsif key == "handle"
          success = Ops.is(value, "void (any, string, map)") ||
            Ops.is_symbol?(value)
        elsif key == "store"
          success = Ops.is(value, "void (any, string)")
        elsif key == "cleanup"
          success = Ops.is(value, "void (any, string)")
        elsif key == "validate_function"
          success = Ops.is(value, "boolean (any, string, map)")
        elsif key == "optional"
          success = Ops.is_boolean?(value)
        elsif key == "label_func"
          success = Ops.is(value, "string (any, string)")
        else
          return CWM.ValidateValueType(key, value, widget)
        end
      elsif key == "id2key"
        success = Ops.is(value, "string (map, any)")
      elsif key == "ids"
        success = Ops.is(value, "list (map)")
      elsif key == "option_delete"
        success = Ops.is(value, "boolean (any, string)")
      elsif key == "summary"
        success = Ops.is(value, "string (any, string)")
      elsif key == "label_func"
        success = Ops.is(value, "string (any, string)")
      elsif key == "option_move"
        success = Ops.is(value, "any (any, string, symbol)")
      elsif key == "options"
        success = Ops.is(value, "map <string, any>")
      elsif key == "add_items"
        success = Ops.is_list?(value)
      end

      if !success
        Builtins.y2error(
          "Wrong type of option %1 in description map of %2",
          key,
          widget
        )
      end

      nil
    end

    # Validate the table description
    # @param [Hash{String => Object}] descr a map containing the table description
    # @return [Boolean] true if validation succeeded
    def ValidateTableDescr(key, descr)
      descr = deep_copy(descr)
      ret = true
      Builtins.foreach(descr) do |k, v|
        ret = ValidateValueType(k, v, key, false) && ret
      end
      options = Ops.get_map(descr, "options", {})
      Builtins.foreach(options) do |w_key, v|
        des = Convert.convert(
          v,
          from: "any",
          to:   "map <string, map <string, any>>"
        )
        Builtins.foreach(des) do |group, d|
          if group != "table" && group != "popup"
            Builtins.y2error("Unknown entry in option %1: %2", w_key, group)
          end
          Builtins.foreach(d) do |key2, value|
            ValidateValueType(key2, value, w_key, true)
          end
        end
      end
      ret
    end

    # Get option key from the option id
    # global only because of testsuites
    # @param [Hash{String => Object}] descr map description of the table
    # @param [Object] opt_id any id of the option
    # @return [String] option key
    def id2key(descr, opt_id)
      descr = deep_copy(descr)
      opt_id = deep_copy(opt_id)
      if !opt_id.nil? && Ops.is_string?(opt_id) &&
          Ops.greater_or_equal(Builtins.size(Convert.to_string(opt_id)), 7) &&
          Builtins.substring(Convert.to_string(opt_id), 0, 7) == "____sep"
        return "____sep"
      end
      toEval = Convert.convert(
        Ops.get(descr, "id2key"),
        from: "any",
        to:   "string (map, any)"
      )

      toEval.nil? ? Convert.to_string(opt_id) : toEval.call(descr, opt_id)
    end

    # Get option description map from the key
    # global only because of testsuites
    # @param [Hash{String => Object}] descr map description of the table
    # @param [String] opt_key string option key
    # @return [Hash] option description map
    def key2descr(descr, opt_key)
      descr = deep_copy(descr)
      options = Ops.get_map(descr, "options", {})
      opt_descr = Ops.get_map(options, opt_key, {})
      # a copy wanted here
      opt_descr = Builtins.add(opt_descr, "_cwm_key", opt_key)
      # a deep copy
      Ops.set(
        opt_descr,
        "table",
        Builtins.add(Ops.get_map(opt_descr, "table", {}), "_cwm_key", opt_key)
      )
      Ops.set(
        opt_descr,
        "popup",
        Builtins.add(Ops.get_map(opt_descr, "popup", {}), "_cwm_key", opt_key)
      )
      if Ops.get(opt_descr, ["popup", "label"]).nil?
        Ops.set(
          opt_descr,
          ["popup", "label"],
          Ops.get_string(opt_descr, ["table", "label"], opt_key)
        )
      end
      deep_copy(opt_descr)
    end

    # Update the option description map in order to contain handlers of
    #  all needed functions
    # global only because of testsuites
    # @param [Hash{String => Object}] opt_descr map option description map
    # @param [Hash] fallbacks map of fallback handlers
    # @return [Hash] updated option description map
    def updateOptionMap(opt_descr, fallbacks)
      opt_descr = deep_copy(opt_descr)
      fallbacks = deep_copy(fallbacks)
      # ensure that the submaps exist
      Ops.set(opt_descr, "table", Ops.get_map(opt_descr, "table", {}))
      Ops.set(opt_descr, "popup", Ops.get_map(opt_descr, "popup", {}))
      Builtins.foreach(["init", "store"]) do |k|
        if !Builtins.haskey(Ops.get_map(opt_descr, "popup", {}), k) &&
            Builtins.haskey(fallbacks, k)
          Ops.set(opt_descr, ["popup", k], Ops.get(fallbacks, k))
        end
      end
      if !Builtins.haskey(Ops.get_map(opt_descr, "table", {}), "summary") &&
          Builtins.haskey(fallbacks, "summary")
        Ops.set(opt_descr, ["table", "summary"], Ops.get(fallbacks, "summary"))
      end
      if !Builtins.haskey(Ops.get_map(opt_descr, "table", {}), "label_func") &&
          Builtins.haskey(fallbacks, "label_func")
        Ops.set(
          opt_descr,
          ["table", "label_func"],
          Ops.get(fallbacks, "label_func")
        )
      end
      if !Builtins.haskey(Ops.get_map(opt_descr, "table", {}), "changed") &&
          Builtins.haskey(fallbacks, "changed")
        Ops.set(opt_descr, ["table", "changed"], Ops.get(fallbacks, "changed"))
      end
      if Ops.get_string(opt_descr, "_cwm_key", "") == "____sep" &&
          Ops.get_string(opt_descr, ["table", "label"], "") == ""
        Ops.set(opt_descr, ["table", "label"], "--------------------")
      end
      deep_copy(opt_descr)
    end

    # Get the left column of the table
    # @param [Object] opt_id any option id
    # @param [Hash{String => Object}] opt_descr map option description map
    # @return [String] text to the table
    def tableEntryKey(opt_id, opt_descr)
      opt_id = deep_copy(opt_id)
      opt_descr = deep_copy(opt_descr)
      opt_key = Ops.get_string(opt_descr, "_cwm_key", "")
      label = Ops.get_string(
        opt_descr,
        ["table", "label"],
        Builtins.sformat("%1", opt_key)
      )
      if Builtins.haskey(Ops.get_map(opt_descr, "table", {}), "label_func")
        label_func = Convert.convert(
          Ops.get(opt_descr, ["table", "label_func"]),
          from: "any",
          to:   "string (any, string)"
        )
        label = label_func.call(opt_id, opt_key)
      end
      label
    end

    # Get value to the table entry
    # @param [Object] opt_id any option id
    # @param [Hash{String => Object}] opt_descr map option description map
    # @return [String] text to the table
    def tableEntryValue(opt_id, opt_descr)
      opt_id = deep_copy(opt_id)
      opt_descr = deep_copy(opt_descr)
      opt_key = Ops.get_string(opt_descr, "_cwm_key", "")
      toEval = Convert.convert(
        Ops.get(opt_descr, ["table", "summary"]),
        from: "any",
        to:   "string (any, string)"
      )
      return toEval.call(opt_id, opt_key) if !toEval.nil?
      ""
    end

    # Realize if table entry was changed
    # @param [Object] opt_id any option id
    # @param [Hash{String => Object}] opt_descr map option description map
    # @return [Boolean] true if was changed
    def tableEntryChanged(opt_id, opt_descr)
      opt_id = deep_copy(opt_id)
      opt_descr = deep_copy(opt_descr)
      opt_key = Ops.get_string(opt_descr, "_cwm_key", "")
      toEval = Convert.convert(
        Ops.get(opt_descr, ["table", "changed"]),
        from: "any",
        to:   "boolean (any, string)"
      )
      return toEval.call(opt_id, opt_key) if !toEval.nil?
      false
    end

    # Delete an item from the table
    # Just a wrapper for module-specific function
    # @param [Object] opt_id any option id
    # @param [Hash{String => Object}] descr map table description map
    # @return [Boolean] true if was really deleted
    def deleteTableItem(opt_id, descr)
      opt_id = deep_copy(opt_id)
      descr = deep_copy(descr)
      toEval = Convert.convert(
        Ops.get(descr, "option_delete"),
        from: "any",
        to:   "boolean (any, string)"
      )
      if nil != toEval
        opt_key = id2key(descr, opt_id)
        return toEval.call(opt_id, opt_key)
      end
      false
    end

    # Enable or disable the Delete and up/down buttons
    # @param [Hash{String => Object}] descr map table description map
    # @param [Hash{String => Object}] opt_descr map selected option description map
    def updateButtons(descr, opt_descr)
      descr = deep_copy(descr)
      opt_descr = deep_copy(opt_descr)
      if Ops.get_boolean(descr, ["_cwm_attrib", "add_delete_buttons"], true)
        UI.ChangeWidget(
          Id(:_tp_delete),
          :Enabled,
          Ops.get_boolean(opt_descr, ["table", "optional"], true)
        )
      end
      if Ops.get_boolean(descr, ["_cwm_attrib", "edit_button"], true)
        UI.ChangeWidget(
          Id(:_tp_edit),
          :Enabled,
          !Ops.get_boolean(opt_descr, ["table", "immutable"], false)
        )
      end
      if Ops.get_boolean(descr, ["_cwm_attrib", "up_down_buttons"], false)
        UI.ChangeWidget(
          Id(:_tp_up),
          :Enabled,
          Ops.get_boolean(opt_descr, ["table", "ordering"], true)
        )
        UI.ChangeWidget(
          Id(:_tp_down),
          :Enabled,
          Ops.get_boolean(opt_descr, ["table", "ordering"], true)
        )
      end

      nil
    end

    # Move table item up or down
    # Just a wrapper for module-specific function
    # @param [Object] opt_id any option id
    # @param [Hash{String => Object}] descr map table description map
    # @param [Symbol] dir symbol `up or `down (according to the button user pressed)
    # @return [Object] new id of selected option, nil if wasn't reordered
    def moveTableItem(opt_id, descr, dir)
      opt_id = deep_copy(opt_id)
      descr = deep_copy(descr)
      toEval = Convert.convert(
        Ops.get(descr, "option_move"),
        from: "any",
        to:   "any (any, string, symbol)"
      )
      return toEval.call(opt_id, id2key(descr, opt_id), dir) if nil != toEval
      nil
    end

    # Redraw completely the table
    # @param [Hash{String => Object}] descr map description map of the whole table
    # @param [Boolean] update_buttons boolean true if buttons status (enabled/disabled)
    #  should be updated according to currently selected item
    def TableRedraw(descr, update_buttons)
      descr = deep_copy(descr)
      id_list = getIdList(descr)
      if @previous_selected_item.nil?
        @previous_selected_item = Ops.get(id_list, 0)
      end
      entries = Builtins.maplist(id_list) do |opt_id|
        opt_val = ""
        opt_changed = false
        opt_key = id2key(descr, opt_id)
        opt_descr = key2descr(descr, opt_key)
        opt_descr = updateOptionMap(
          opt_descr,
          Ops.get_map(descr, "fallback", {})
        )
        label = tableEntryKey(opt_id, opt_descr)
        if opt_key != "____sep"
          opt_val = tableEntryValue(opt_id, opt_descr)
          opt_changed = tableEntryChanged(opt_id, opt_descr)
        end
        if update_buttons && opt_id == @previous_selected_item
          updateButtons(descr, opt_descr)
        end
        if Ops.get_boolean(descr, ["_cwm_attrib", "changed_column"], false)
          next Item(
            Id(opt_id),
            opt_changed ? "*" : "",
            label,
            Builtins.sformat("%1", opt_val)
          )
        end
        Item(Id(opt_id), label, Builtins.sformat("%1", opt_val))
      end
      UI.ChangeWidget(Id(:_tp_table), :Items, entries)
      UI.SetFocus(Id(:_tp_table))

      nil
    end

    # Displaye popup for option to edit choosing
    # @param [Array] possible a list of strings or items of all possible options
    #   to provide
    # @param [Boolean] editable boolean true means that it is possible to add non-listed
    #   options
    # @param [Hash{String => Object}] descr a map table description map
    # @return [String] option identifies, nil if canceled
    def askForNewOption(possible, editable, descr)
      possible = deep_copy(possible)
      descr = deep_copy(descr)
      do_sort = !Ops.get_boolean(descr, "add_items_keep_order", false)
      possible = Builtins.sort(possible) if do_sort
      val2key = {}
      known_keys = {}
      possible = Builtins.maplist(possible) do |p|
        next if !Ops.is_string?(p)
        opt_descr = key2descr(descr, Convert.to_string(p))
        label = Ops.get_string(
          opt_descr,
          ["table", "label"],
          Builtins.sformat("%1", p)
        )
        Ops.set(known_keys, Convert.to_string(p), true)
        Ops.set(val2key, label, Convert.to_string(p))
        Item(Id(p), label)
      end
      widget = HBox(
        HSpacing(1),
        VBox(
          VSpacing(1),
          ComboBox(
            Id(:optname),
            editable ? Opt(:editable) : Opt(),
            # combobox header
            _("&Selected Option"),
            possible
          ),
          VSpacing(1),
          HBox(
            HStretch(),
            PushButton(Id(:_tp_ok), Opt(:key_F10, :default), Label.OKButton),
            HSpacing(1),
            PushButton(Id(:_tp_cancel), Opt(:key_F9), Label.CancelButton),
            HStretch()
          ),
          VSpacing(1)
        ),
        HSpacing(1)
      )
      UI.OpenDialog(widget)
      begin
        UI.SetFocus(Id(:optname))
        ret = nil
        option = nil
        while ret != :_tp_ok && ret != :_tp_cancel
          ret = UI.UserInput
          if ret == :_tp_ok
            option = Convert.to_string(UI.QueryWidget(Id(:optname), :Value))
          end
        end
      ensure
        UI.CloseDialog
      end
      return nil if ret == :_tp_cancel
      return option if Ops.get(known_keys, option, false)
      Ops.get(val2key, option, option)
    end

    # Display and handle the popup for option
    # @param [Hash{String => Object}] option map one option description map that is modified in order
    #   to contain the option name and more percise option identification
    # @return [Symbol] `_tp_ok or `_tp_cancel
    def singleOptionEditPopup(option)
      option = deep_copy(option)
      opt_key = Ops.get_string(option, "_cwm_key", "")
      opt_id = Ops.get(option, "_cwm_id")

      label = Builtins.sformat(
        "%1",
        Ops.get_string(option, ["table", "label"], opt_key)
      )
      header = HBox(
        # heading / label
        Heading(_("Current Option: ")),
        Label(label),
        HStretch()
      )
      popup_descr = CWM.prepareWidget(Ops.get_map(option, "popup", {}))
      widget = Ops.get_term(popup_descr, "widget", VBox())
      help = Ops.get_string(popup_descr, "help", "")
      help = "" if help.nil?
      contents = HBox(
        HSpacing(1),
        VBox(
          VSpacing(1),
          Left(header),
          VSpacing(1),
          help == "" ? VSpacing(0) : Left(Label(help)),
          VSpacing(help == "" ? 0 : 1),
          Left(ReplacePoint(Id(:value_rp), widget)),
          VSpacing(1),
          HBox(
            HStretch(),
            PushButton(Id(:_tp_ok), Opt(:key_F10, :default), Label.OKButton),
            HSpacing(1),
            PushButton(Id(:_tp_cancel), Opt(:key_F9), Label.CancelButton),
            HStretch()
          ),
          VSpacing(1)
        ),
        HSpacing(1)
      )
      UI.OpenDialog(contents)
      begin
        if Ops.get(popup_descr, "init")
          toEval = Convert.convert(
            Ops.get(popup_descr, "init"),
            from: "any",
            to:   "void (any, string)"
          )
          toEval.call(opt_id, opt_key)
        end
        ret = nil
        while ret != :_tp_ok && ret != :_tp_cancel
          event_descr2 = UI.WaitForEvent
          event_descr2 = { "ID" => :_tp_ok } if Mode.test
          ret = Ops.get(event_descr2, "ID")
          if Ops.get(popup_descr, "handle")
            toEval = Convert.convert(
              Ops.get(popup_descr, "handle"),
              from: "any",
              to:   "void (any, string, map)"
            )
            toEval.call(opt_id, opt_key, event_descr2)
          end

          next if ret != :_tp_ok

          val_type = Ops.get_symbol(popup_descr, "validate_type")
          if val_type == :function
            toEval = Convert.convert(
              Ops.get(popup_descr, "validate_function"),
              from: "any",
              to:   "boolean (any, string, map)"
            )
            if !toEval.nil?
              ret = nil if !toEval.call(opt_id, opt_key, event_descr2)
            end
          elsif !CWM.validateWidget(popup_descr, event_descr2, opt_key)
            ret = nil
          end
        end
        if ret == :_tp_ok && Ops.get(popup_descr, "store")
          toEval = Convert.convert(
            Ops.get(popup_descr, "store"),
            from: "any",
            to:   "void (any, string)"
          )
          toEval.call(opt_id, opt_key)
        end
      ensure
        UI.CloseDialog
      end
      Convert.to_symbol(ret)
    end

    # functions

    # Disable whole table
    # @param [Hash{String => Object}] descr map table widget description map
    def DisableTable(descr)
      descr = deep_copy(descr)
      UI.ChangeWidget(Id(:_tp_table), :Enabled, false)
      if Ops.get_boolean(descr, ["_cwm_attrib", "edit_button"], true)
        UI.ChangeWidget(Id(:_tp_edit), :Enabled, false)
      end
      if Ops.get_boolean(descr, ["_cwm_attrib", "add_delete_buttons"], true)
        UI.ChangeWidget(Id(:_tp_delete), :Enabled, false)
        UI.ChangeWidget(Id(:_tp_add), :Enabled, false)
      end
      if Ops.get_boolean(descr, ["_cwm_attrib", "up_down_buttons"], false)
        UI.ChangeWidget(Id(:_tp_up), :Enabled, false)
        UI.ChangeWidget(Id(:_tp_down), :Enabled, false)
      end

      nil
    end

    # Enable whole table (except buttons that should be grayed according to
    # currently selected table row
    # @param [Hash{String => Object}] descr map table widget description map
    def EnableTable(descr)
      descr = deep_copy(descr)
      UI.ChangeWidget(Id(:_tp_table), :Enabled, true)
      if Ops.get_boolean(descr, ["_cwm_attrib", "edit_button"], true)
        UI.ChangeWidget(Id(:_tp_edit), :Enabled, true)
      end
      if Ops.get_boolean(descr, ["_cwm_attrib", "add_delete_buttons"], true)
        UI.ChangeWidget(Id(:_tp_add), :Enabled, false)
      end

      opt_id = UI.QueryWidget(Id(:_tp_table), :CurrentItem)
      opt_key = id2key(descr, opt_id)
      option_map = key2descr(descr, opt_key)
      updateButtons(descr, option_map)

      nil
    end

    # Initialize the displayed table
    # @param [Hash{String => Object}] descr map description map of the whole table
    # @param [String] key table widget key
    def TableInit(descr, key)
      descr = deep_copy(descr)
      @previous_selected_item = nil
      Ops.set(descr, "_cwm_key", key)
      TableRedraw(descr, true)

      nil
    end

    # Handle the event that happened on the table
    # @param [Hash{String => Object}] descr map description of the table
    # @param [String] key table widget key
    # @param [Hash] event_descr map event to handle
    # @return [Symbol] modified event if needed
    def TableHandle(descr, key, event_descr)
      descr = deep_copy(descr)
      event_descr = deep_copy(event_descr)
      event_id = Ops.get(event_descr, "ID")
      UI.SetFocus(Id(:_tp_table))
      if event_id == :_tp_table
        if Ops.get_string(event_descr, "EventReason", "") == "Activated" &&
            Ops.get_string(event_descr, "EventType", "") == "WidgetEvent" &&
            UI.WidgetExists(Id(:_tp_edit))
          event_id = :_tp_edit
        end
      end
      if event_id == :_tp_edit || event_id == :_tp_add
        opt_key = nil
        opt_id = nil

        if event_id == :_tp_add
          add_unlisted = Ops.get_boolean(descr, "add_unlisted", true)
          if !add_unlisted &&
              Builtins.size(Ops.get_list(descr, "add_items", [])) == 1
            opt_key = Ops.get_string(descr, ["add_items", 0], "")
          else
            add_opts = Ops.get_list(descr, "add_items", [])
            ids = getIdList(descr)
            present = Builtins.maplist(ids) { |i| id2key(descr, i) }
            if !Ops.get_boolean(descr, ["_cwm_attrib", "unique_keys"], false)
              present = Builtins.filter(present) do |i|
                opt_descr = key2descr(descr, i)
                !Ops.get_boolean(opt_descr, ["table", "optional"], true)
              end
            end
            add_opts = Builtins.filter(add_opts) do |o|
              !Builtins.contains(present, o)
            end
            selected = false
            until selected
              opt_key = askForNewOption(add_opts, add_unlisted, descr)
              return nil if opt_key.nil?
              if Builtins.contains(present, opt_key)
                Report.Error(
                  # error report
                  _("The selected option is already present.")
                )
              else
                selected = true
              end
            end
          end
          return nil if opt_key.nil?
        elsif event_id == :_tp_edit
          opt_id = UI.QueryWidget(Id(:_tp_table), :CurrentItem)
          opt_key = id2key(descr, opt_id)
        end
        option_map = key2descr(descr, opt_key)
        toEval = Ops.get(option_map, ["table", "handle"])
        if !toEval.nil?
          #		if (is (toEval, symbol))
          if !Ops.is(toEval, "symbol (any, string, map)")
            ret2 = Convert.to_symbol(toEval)
            return ret2
          else
            toEval_c = Convert.convert(
              Ops.get(option_map, ["table", "handle"]),
              from: "any",
              to:   "symbol (any, string, map)"
            )
            ret2 = toEval_c.call(opt_id, opt_key, event_descr)
            return ret2 if ret2 != :_tp_normal
          end
        end
        Ops.set(option_map, "_cwm_id", opt_id)
        Ops.set(option_map, "_cwm_key", opt_key)
        # add generic handlers if needed
        option_map = updateOptionMap(
          option_map,
          Ops.get_map(descr, "fallback", {})
        )
        ret = singleOptionEditPopup(option_map)
        if ret == :_tp_ok
          if event_id == :_tp_add
            TableInit(descr, key)
          elsif event_id == :_tp_edit
            column = descr.fetch("_cwm_attrib", {}).fetch("changed_column", false) ? 2 : 1
            UI.ChangeWidget(
              Id(:_tp_table),
              term(:Item, opt_id, column),
              tableEntryValue(opt_id, option_map)
            )
            # also redraw the key field as it can be changed
            column = Ops.subtract(column, 1)
            UI.ChangeWidget(
              Id(:_tp_table),
              term(:Item, opt_id, column),
              tableEntryKey(opt_id, option_map)
            )
            if Ops.get_boolean(descr, ["_cwm_attrib", "changed_column"], false)
              UI.ChangeWidget(
                Id(:_tp_table),
                term(:Item, opt_id, 0),
                tableEntryChanged(opt_id, option_map) ? "*" : ""
              )
            end
          end
        end
      elsif event_id == :_tp_delete
        opt_id = UI.QueryWidget(Id(:_tp_table), :CurrentItem)
        TableInit(descr, key) if deleteTableItem(opt_id, descr)
      elsif event_id == :_tp_table
        opt_id = UI.QueryWidget(Id(:_tp_table), :CurrentItem)
        key2 = id2key(descr, opt_id)
        if key2 == "____sep"
          id_list = getIdList(descr)
          previous_index = 0
          if !@previous_selected_item.nil?
            previous_index = -1
            Builtins.find(id_list) do |e|
              previous_index = Ops.add(previous_index, 1)
              e == @previous_selected_item
            end
          end
          current_index = -1
          Builtins.find(id_list) do |e|
            current_index = Ops.add(current_index, 1)
            e == opt_id
          end
          step = if current_index == 0
                   1
                 elsif Ops.add(current_index, 1) == Builtins.size(id_list)
                   -1
                 elsif Ops.greater_or_equal(current_index, previous_index)
                   1
                 else
                   -1
          end
          new_index = Ops.add(current_index, step)
          opt_id = Ops.get(id_list, new_index)
          UI.ChangeWidget(Id(:_tp_table), :CurrentItem, opt_id)
        end
        @previous_selected_item = deep_copy(opt_id)

        opt_descr = key2descr(descr, id2key(descr, opt_id))
        updateButtons(descr, opt_descr)
      elsif event_id == :_tp_up || event_id == :_tp_down
        opt_id = UI.QueryWidget(Id(:_tp_table), :CurrentItem)
        opt_id = moveTableItem(opt_id, descr, event_id == :_tp_up ? :up : :down)
        if nil != opt_id
          TableRedraw(descr, false)
          UI.ChangeWidget(Id(:_tp_table), :CurrentItem, opt_id)

          opt_descr = key2descr(descr, id2key(descr, opt_id))
          updateButtons(descr, opt_descr)
        end
      end
      nil
    end

    # Wrapper for TableInit using CWM::GetProcessedWidget () for getting
    # widget description map
    # @param [String] key any widget key
    def TableInitWrapper(key)
      TableInit(CWM.GetProcessedWidget, key)

      nil
    end

    # Wrapper for TableHandle using CWM::GetProcessedWidget () for getting
    # widget description map
    # @param [String] key any widget key
    # @param [Hash] event_descr map event description map
    # @return [Symbol] return value for wizard sequencer or nil
    def TableHandleWrapper(key, event_descr)
      event_descr = deep_copy(event_descr)
      TableHandle(CWM.GetProcessedWidget, key, event_descr)
    end

    # Get the map with the table widget
    # @param [Hash{String => Object}] attrib map table attributes
    # @param [Hash{String => Object}] widget_descr map widget description map of the table, will be
    #  unioned with the generated map
    # @return [Hash] table widget
    def CreateTableDescr(attrib, widget_descr)
      attrib = deep_copy(attrib)
      widget_descr = deep_copy(widget_descr)
      ValidateTableAttr(attrib)
      add_button = if Ops.get_boolean(attrib, "add_delete_buttons", true)
                     PushButton(Id(:_tp_add), Opt(:key_F3), Label.AddButton)
                   else
                     HSpacing(0)
                   end
      edit_button = if Ops.get_boolean(attrib, "edit_button", true)
                      PushButton(Id(:_tp_edit), Opt(:key_F4), Label.EditButton)
                    else
                      HSpacing(0)
                    end
      delete_button = if Ops.get_boolean(attrib, "add_delete_buttons", true)
                        PushButton(Id(:_tp_delete), Opt(:key_F5), Label.DeleteButton)
                      else
                        HSpacing(0)
                      end
      table_header = if Ops.get_boolean(attrib, "changed_column", false)
                       Header(
                         # table header, shortcut for changed, keep very short
                         _("Ch."),
                         # table header
                         _("Option"),
                         # table header
                         _("Value")
                       )
                     else
                       Header(
                         # table header
                         _("Option"),
                         # table header
                         _("Value")
                       )
                     end

      replace_point = ReplacePoint(Id(:_tp_table_repl), HSpacing(0))
      # help 1/4
      help = _(
        "<p><b><big>Editing the Settings</big></b><br>\n" \
          "To edit the settings, choose the appropriate\n" \
          "entry of the table then click <b>Edit</b>.</p>"
      )
      if Ops.get_boolean(attrib, "add_delete_buttons", true)
        # help 2/4, optional
        help = Ops.add(
          help,
          _(
            "<p>To add a new option, click <b>Add</b>. To remove\nan option, select it and click <b>Delete</b>.</p>"
          )
        )
      end

      if Ops.get_boolean(attrib, "changed_column", false)
        # help 3/4, optional
        help = Ops.add(
          help,
          _(
            "<P>The <B>Ch.</B> column of the table shows \nwhether the option was changed.</P>"
          )
        )
      end

      if Ops.get_boolean(attrib, "up_down_buttons", false)
        # help 4/4, optional
        help = Ops.add(
          help,
          _(
            "<p>To reorder the options, select an option\n" \
              "and use <b>Up</b> and <b>Down</b> to move it up or down\n" \
              "in the list.</p>"
          )
        )
      end

      up_down = if Ops.get_boolean(attrib, "up_down_buttons", false)
                  VBox(
                    VStretch(),
                    # push button
                    PushButton(Id(:_tp_up), _("&Up")),
                    # push button
                    PushButton(Id(:_tp_down), _("&Down")),
                    VStretch()
                  )
                else
                  HSpacing(0)
                end

      ret = Convert.convert(
        Builtins.union(
          {
            "custom_widget"    => HBox(
              HSpacing(2),
              VBox(
                HBox(
                  Table(
                    Id(:_tp_table),
                    Opt(:immediate, :notify, :keepSorting),
                    table_header,
                    []
                  ),
                  up_down
                ),
                HBox(
                  add_button,
                  edit_button,
                  delete_button,
                  HStretch(),
                  replace_point
                )
              ),
              HSpacing(2)
            ),
            "_cwm_attrib"      => attrib,
            "widget"           => :custom,
            "help"             => help,
            "_cwm_do_validate" => fun_ref(
              method(:ValidateTableDescr),
              "boolean (string, map <string, any>)"
            )
          },
          widget_descr
        ),
        from: "map",
        to:   "map <string, any>"
      )

      if !Builtins.haskey(ret, "init")
        Ops.set(
          ret,
          "init",
          fun_ref(method(:TableInitWrapper), "void (string)")
        )
      end
      if !Builtins.haskey(ret, "handle")
        Ops.set(
          ret,
          "handle",
          fun_ref(method(:TableHandleWrapper), "symbol (string, map)")
        )
      end

      deep_copy(ret)
    end

    publish function: :id2key, type: "string (map <string, any>, any)"
    publish function: :key2descr, type: "map <string, any> (map <string, any>, string)"
    publish function: :updateOptionMap, type: "map <string, any> (map <string, any>, map)"
    publish function: :tableEntryChanged, type: "boolean (any, map <string, any>)"
    publish function: :deleteTableItem, type: "boolean (any, map <string, any>)"
    publish function: :updateButtons, type: "void (map <string, any>, map <string, any>)"
    publish function: :askForNewOption, type: "string (list, boolean, map <string, any>)"
    publish function: :singleOptionEditPopup, type: "symbol (map <string, any>)"
    publish function: :DisableTable, type: "void (map <string, any>)"
    publish function: :EnableTable, type: "void (map <string, any>)"
    publish function: :TableInit, type: "void (map <string, any>, string)"
    publish function: :TableHandle, type: "symbol (map <string, any>, string, map)"
    publish function: :TableInitWrapper, type: "void (string)"
    publish function: :TableHandleWrapper, type: "symbol (string, map)"
    publish function: :CreateTableDescr, type: "map <string, any> (map <string, any>, map <string, any>)"
  end

  TablePopup = TablePopupClass.new
  TablePopup.main
end
