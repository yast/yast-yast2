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
# File:	modules/CWMTable.ycp
# Package:	Table dialogs backend
# Summary:	Routines for Unified Table widget
# Authors:	Josef Reidinger <jreidinger@suse.cz>
#
# $Id: CWMTable.ycp
#
require "yast"

module Yast
  class CWMTableClass < Module
    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "CWM"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Report"
    end

    # local functions

    # Validate table options specifyign attributesA
    # @param [Hash{String => Object}] attr a map of table attributes
    # @return [Boolean] true if validation succeeded
    def ValidateTableAttr(attr)
      attr = deep_copy(attr)
      types = {
        "add_delete_buttons" => "boolean",
        "edit_button"        => "boolean",
        "up_down_buttons"    => "boolean",
        "custom_button"      => "boolean",
        "custom_button_name" => "string",
        "custom_handle"      => "symbol(string,map)",
        "header"             => "term",
        "add"                => "symbol(string,map,integer)",
        "edit"               => "symbol(string,map,integer)",
        "delete"             => "symbol(string,map,integer)",
        "updown"             => "symbol(string,map,boolean,integer)"
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
    # @param popup boolean true if is option of a popup
    # @return [Boolean] true if validation succeeded
    def ValidateValueType(key, value, widget)
      value = deep_copy(value)
      success = true
      success = Ops.is_string?(value) if key == "help"

      if !success
        Builtins.y2error(
          "Wrong type of option %1 in description map of %2",
          key,
          widget
        )
      end

      success
    end

    # Validate the table description
    # @param [Hash{String => Object}] descr a map containing the table description
    # @return [Boolean] true if validation succeeded
    def ValidateTableDescr(key, descr)
      descr = deep_copy(descr)
      ret = true
      Builtins.foreach(descr) do |k, v|
        ret = ValidateValueType(k, v, key) && ret
      end
      ret
    end

    def getItemId(ter)
      ter = deep_copy(ter)
      args = Builtins.argsof(ter)
      args = Builtins.filter(args) do |t|
        if Ops.is_term?(t) && Builtins.symbolof(Convert.to_term(t)) == :id
          next true
        end
        false
      end
      targs = Convert.convert(args, from: "list", to: "list <term>")
      if Builtins.size(targs) == 1
        return Ops.get(
          Convert.convert(
            Builtins.argsof(Ops.get(targs, 0)),
            from: "list",
            to:   "list <string>"
          ),
          0
        )
      end
      nil
    end

    # Enable or disable the Delete and up/down buttons
    # @param [Hash{String => Object}] descr map table description map
    # @param opt_descr map selected option description map
    def updateButtons(descr)
      descr = deep_copy(descr)
      Builtins.y2milestone("update buttons")
      id = Convert.to_string(UI.QueryWidget(Id(:_tw_table), :CurrentItem))
      item_list = Convert.convert(
        UI.QueryWidget(Id(:_tw_table), :Items),
        from: "any",
        to:   "list <term>"
      )
      index = -1
      counter = 0
      max = Ops.subtract(item_list.nil? ? 0 : Builtins.size(item_list), 1)
      Builtins.foreach(item_list) do |t|
        index = counter if getItemId(t) == id
        counter = Ops.add(counter, 1)
      end
      if Ops.get_boolean(descr, ["_cwm_attrib", "up_down_buttons"], false)
        if Ops.less_than(max, 1) || index == -1
          Builtins.y2milestone("short list")
          UI.ChangeWidget(Id(:_tw_up), :Enabled, false)
          UI.ChangeWidget(Id(:_tw_down), :Enabled, false)
        else
          if index == 0
            Builtins.y2milestone("first item")
            UI.ChangeWidget(Id(:_tw_up), :Enabled, false)
            UI.ChangeWidget(Id(:_tw_down), :Enabled, true)
          elsif index == max
            Builtins.y2milestone("last item")
            UI.ChangeWidget(Id(:_tw_up), :Enabled, true)
            UI.ChangeWidget(Id(:_tw_down), :Enabled, false)
          else
            UI.ChangeWidget(Id(:_tw_up), :Enabled, true)
            UI.ChangeWidget(Id(:_tw_down), :Enabled, true)
          end
        end
      else
        UI.ChangeWidget(Id(:_tw_up), :Enabled, false)
        UI.ChangeWidget(Id(:_tw_down), :Enabled, false)
      end

      nil
    end

    # functions

    # Initialize the displayed table
    # @param [Hash{String => Object}] descr map description map of the whole table
    # @param [String] key table widget key
    def TableInit(descr, key)
      descr = deep_copy(descr)
      Ops.set(descr, "_cwm_key", key)

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
      attrib = Ops.get_map(descr, "_cwm_attrib", {})
      ret = nil
      id = Convert.to_string(UI.QueryWidget(Id(:_tw_table), :CurrentItem))
      item_list = Convert.convert(
        UI.QueryWidget(Id(:_tw_table), :Items),
        from: "any",
        to:   "list <term>"
      )
      index = -1
      counter = 0
      Builtins.foreach(item_list) do |t|
        index = counter if getItemId(t) == id
        counter = Ops.add(counter, 1)
      end
      if event_id == :_tw_table
        if Ops.get_string(event_descr, "EventReason", "") == "Activated" &&
            Ops.get_string(event_descr, "EventType", "") == "WidgetEvent" &&
            UI.WidgetExists(Id(:_tw_edit))
          event_id = :_tw_edit
        end
      end
      if event_id == :_tw_edit
        edit_handle = Convert.convert(
          Ops.get(attrib, "edit"),
          from: "any",
          to:   "symbol (string, map, integer)"
        )
        ret = edit_handle.call(key, event_descr, index) if !edit_handle.nil?
      elsif event_id == :_tw_add
        add_handle = Convert.convert(
          Ops.get(attrib, "add"),
          from: "any",
          to:   "symbol (string, map, integer)"
        )
        ret = add_handle.call(key, event_descr, index) if !add_handle.nil?
      elsif event_id == :_tw_delete
        delete_handle = Convert.convert(
          Ops.get(attrib, "delete"),
          from: "any",
          to:   "symbol (string, map, integer)"
        )
        ret = delete_handle.call(key, event_descr, index) if delete_handle
      elsif event_id == :_tw_custom
        custom_handle = Convert.convert(
          Ops.get(attrib, "custom_handle"),
          from: "any",
          to:   "symbol (string, map, integer)"
        )
        ret = custom_handle.call(key, event_descr, index) if custom_handle
      elsif event_id == :_tw_up || event_id == :_tw_down
        up = event_id == :_tw_up
        updown_handle = Convert.convert(
          Ops.get(attrib, "updown"),
          from: "any",
          to:   "symbol (string, map, boolean, integer)"
        )
        if !updown_handle.nil? && !(index == 0 && up) &&
            !(index == Ops.subtract(Builtins.size(item_list), 1) && !up)
          ret = updown_handle.call(key, event_descr, up, index)
          UI.ChangeWidget(Id(:_tw_table), :CurrentItem, id) if ret.nil?
        end
      end
      updateButtons(descr)
      ret
    end

    # Disable whole table
    # @param [Hash{String => Object}] descr map table widget description map
    def DisableTable(descr)
      descr = deep_copy(descr)
      UI.ChangeWidget(Id(:_tw_table), :Enabled, false)
      if Ops.get_boolean(descr, ["_cwm_attrib", "edit_button"], true)
        UI.ChangeWidget(Id(:_tw_edit), :Enabled, false)
      end
      if Ops.get_boolean(descr, ["_cwm_attrib", "add_delete_buttons"], true)
        UI.ChangeWidget(Id(:_tw_delete), :Enabled, false)
        UI.ChangeWidget(Id(:_tw_add), :Enabled, false)
      end
      if Ops.get_boolean(descr, ["_cwm_attrib", "up_down_buttons"], false)
        UI.ChangeWidget(Id(:_tw_up), :Enabled, false)
        UI.ChangeWidget(Id(:_tw_down), :Enabled, false)
      end
      if Ops.get_boolean(descr, ["_cwm_attrib", "custom_button"], false)
        UI.ChangeWidget(Id(:_tw_custom), :Enabled, false)
      end

      nil
    end

    # Enable whole table (except buttons that should be grayed according to
    # currently selected table row
    # @param [Hash{String => Object}] descr map table widget description map
    def EnableTable(descr)
      descr = deep_copy(descr)
      UI.ChangeWidget(Id(:_tw_table), :Enabled, true)
      if Ops.get_boolean(descr, ["_cwm_attrib", "edit_button"], true)
        UI.ChangeWidget(Id(:_tw_edit), :Enabled, true)
      end
      if Ops.get_boolean(descr, ["_cwm_attrib", "add_delete_buttons"], true)
        UI.ChangeWidget(Id(:_tw_add), :Enabled, true)
      end
      if Ops.get_boolean(descr, ["_cwm_attrib", "custom_button"], false)
        UI.ChangeWidget(Id(:_tw_custom), :Enabled, true)
      end
      TableHandle(descr, "", {})

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
                     PushButton(Id(:_tw_add), Opt(:key_F3, :notify), Label.AddButton)
                   else
                     HSpacing(0)
                   end
      edit_button = if Ops.get_boolean(attrib, "edit_button", true)
                      PushButton(Id(:_tw_edit), Opt(:key_F4, :notify), Label.EditButton)
                    else
                      HSpacing(0)
                    end
      delete_button = if Ops.get_boolean(attrib, "add_delete_buttons", true)
                        PushButton(Id(:_tw_delete), Opt(:key_F5, :notify), Label.DeleteButton)
                      else
                        HSpacing(0)
                      end
      table_header = Ops.get_term(attrib, "header")

      custom_button = if Ops.get_boolean(attrib, "custom_button", false)
                        PushButton(
                          Id(:_tw_custom),
                          Opt(:notify),
                          Ops.get_string(attrib, "custom_button_name", "Custom button")
                        )
                      else
                        HSpacing(0)
                      end

      up_down = if Ops.get_boolean(attrib, "up_down_buttons", false)
                  VBox(
                    VStretch(),
                    # push button
                    PushButton(Id(:_tw_up), Opt(:notify), _("&Up")),
                    # push button
                    PushButton(Id(:_tw_down), Opt(:notify), _("&Down")),
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
                    Id(:_tw_table),
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
                  custom_button
                )
              ),
              HSpacing(2)
            ),
            "_cwm_attrib"      => attrib,
            "widget"           => :custom,
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

    publish function: :TableInit, type: "void (map <string, any>, string)"
    publish function: :DisableTable, type: "void (map <string, any>)"
    publish function: :EnableTable, type: "void (map <string, any>)"
    publish function: :TableInitWrapper, type: "void (string)"
    publish function: :TableHandleWrapper, type: "symbol (string, map)"
    publish function: :CreateTableDescr, type: "map <string, any> (map <string, any>, map <string, any>)"
  end

  CWMTable = CWMTableClass.new
  CWMTable.main
end
