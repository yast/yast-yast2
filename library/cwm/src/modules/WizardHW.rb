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
# File:	modules/WizardHW
# Package:	Base YaST package
# Summary:	Routines for generic hardware summary dialog
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
require "yast"

module Yast
  class WizardHWClass < Module
    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "CWM"
      Yast.import "Label"
      Yast.import "Report"
      Yast.import "Popup"
      Yast.import "Wizard"

      # local store

      # List of items in the currently displayed dialog
      @current_items = []

      # Map of rich text descriptions for all items
      # Contained info can be reachable through current_items, this is for
      # faster access
      @descriptions = {}

      # The last handled UI event
      @last_event = {}

      # The return value to be returned by WizardHW::WaitForEvent ()
      @dialog_ret = nil

      # callbacks

      # Callback
      # Perform an action (when an event which is not handled internally occurred)
      @action_callback = nil

      # Callback
      # Get rich text description of an item.
      # This can be used to set it dynamically
      @get_item_descr_callback = nil

      # Callback
      # Set all the items
      # Should call the SetContents function of this module
      @set_items_callback = nil

      # Callback
      # Select the initial item
      # If not set, the first is selected
      @select_initial_item_callback = nil
    end

    # internal functions

    # Store the event description in internal variable
    # To be used by WizardHW::WaitForEvent function
    # @param [String] selected string the ID of the currently selected item
    # @param [Hash] event a map of the current item
    # @return always a non-nil symbol (needed just to finish event loop
    def SimpleStoreReturnValue(selected, event)
      event = deep_copy(event)
      @dialog_ret = { "event" => event, "selected" => selected }
      :next # anything but nil
    end

    # Set which item is to be selected
    # @param [String] selected string the item that is should be marked as selected
    def _SetSelectedItem(selected)
      if !selected.nil?
        UI.ChangeWidget(Id(:_hw_items), :CurrentItem, selected)
        UI.ChangeWidget(
          Id(:_hw_sum),
          :Value,
          Ops.get(@descriptions, selected, "")
        )
      end

      nil
    end

    # Init function of the widget
    # Used when using the callback interface
    # @param [String] key strnig the widget key
    def Init(_key)
      if !@set_items_callback.nil?
        @set_items_callback.call
      else
        Builtins.y2warning("No initialization callback")
      end
      if !@select_initial_item_callback.nil?
        @select_initial_item_callback.call
      else
        _SetSelectedItem(Ops.get_string(@current_items, [0, "id"]))
      end

      nil
    end

    # Handle function of the widget
    # Used when using the callback interface
    # @param [String] key strnig the widget key
    # @param [String] key strnig the widget key
    # @param [Hash] event map event to be handled
    # @return [Symbol] for wizard sequencer or nil
    def Handle(_key, event)
      event = deep_copy(event)
      @last_event = deep_copy(event)
      current = Convert.to_string(UI.QueryWidget(Id(:_hw_items), :CurrentItem))
      if Ops.get(event, "ID") == :_hw_items
        descr = if @get_item_descr_callback.nil?
                  Ops.get(@descriptions, current, "")
                else
                  @get_item_descr_callback.call(current)
        end
        UI.ChangeWidget(Id(:_hw_sum), :Value, descr)
        return nil
      end
    
      return @action_callback.call(current, event) unless @action_callback.nil?

      ret = Ops.get(event, "ID")

      Ops.is_symbol?(ret) ? Convert.to_symbol(ret) : nil
    end

    # internal functions

    def StoreCurrentItems(items)
      items = deep_copy(items)
      @current_items = deep_copy(items)
      @descriptions = Builtins.listmap(items) do |i|
        { Ops.get_string(i, "id", "") => Ops.get_string(i, "rich_descr", "") }
      end

      nil
    end

    # Get the description label for the action
    # @param [Array] action a list describing the action
    # @return [String] the label of the action
    def GetActionLabel(action)
      action = deep_copy(action)
      fallback = ""
      if Ops.is_string?(Ops.get(action, 0))
        fallback = Ops.get_string(action, 0, "")
      end
      Ops.get_string(action, 1, fallback)
    end

    # Create the Push/Menu button for additional actions
    # @param [Array<Array>] actions a list of the actions
    # @return [Yast::Term] the widget
    def CreateActionsButton(actions)
      actions = deep_copy(actions)
      sz = Builtins.size(actions)
      return Empty() if sz == 0
      if sz == 1
        id = Ops.get(actions, [0, 0])
        if id.nil?
          Builtins.y2error("Unknown ID for button: %1", Ops.get(actions, 0))
          id = "nil"
        end
        return PushButton(Id(id), GetActionLabel(Ops.get(actions, 0, [])))
      end
      items = Builtins.maplist(actions) do |i|
        id = Ops.get(i, 0)
        if id.nil?
          Builtins.y2error("Unknown ID for button: %1", Ops.get(actions, 0))
          id = "nil"
        end
        Item(Id(id), GetActionLabel(i))
      end
      # menu button
      MenuButton(_("&Other"), items)
    end

    # CWM widget

    # Create CWM widtet for the hardware settings
    # NOTE: The Init and Handle callbacks must be defined
    # @note This is a stable API function
    # @param [Array<String>] headers a list of headers of the table
    # @param [Array<Array>] actions a list of additionaly offered actions, see CreateHWDialog
    #  function for details
    # @return a map a widget for CWM
    def CreateWidget(headers, actions)
      headers = deep_copy(headers)
      actions = deep_copy(actions)
      hdr = Header()
      Builtins.foreach(headers) { |hi| hdr = Builtins.add(hdr, hi) }
      item_list = Table(Id(:_hw_items), Opt(:notify, :immediate), hdr)
      buttons = HBox(
        PushButton(Id(:add), Label.AddButton),
        PushButton(Id(:edit), Label.EditButton),
        PushButton(Id(:delete), Label.DeleteButton),
        HStretch(),
        CreateActionsButton(actions)
      )
      item_summary = RichText(Id(:_hw_sum), "")

      contents = VBox(VWeight(3, item_list), VWeight(1, item_summary), buttons)

      handle_events = [:_hw_items, :add, :edit, :delete]
      extra_events = Builtins.maplist(actions) { |i| Ops.get(i, 1) }
      extra_events = Builtins.filter(extra_events) { |i| !i.nil? }
      handle_events = Builtins.merge(handle_events, extra_events)

      ret = {
        "widget"        => :custom,
        "custom_widget" => contents,
        "handle_events" => handle_events
      }

      deep_copy(ret)
    end

    # callback iface

    # Draw the dialog, handle all its events via callbacks
    # @note This is a stable API function
    # @param [Hash] settings a map containing all the settings:
    #  $[
    #   "action_callback" : symbol(string,map<string,any>) -- callback to handle
    #      all events which aren't handled internally, first parameter is
    #      the ID of the selected item, second is the event. If not set,
    #      events which are symbols are returned to wizard sequencer
    #  "set_items_callback" : void() -- callback to set the items to be displayed.
    #      Should called WizardHW::SetContents instead of direct widgets
    #      modification, as it stores the settings also internally. This callback
    #      must be set.
    #  "set_initial_item_callback" : void() -- callback to set the selected item
    #      when dialog initialized. Should call the function
    #      WizardHW::SetSelectedItem instead of manual widget modification.
    #      If not set, the first item is selected.
    #  "item_descr_callback" : string(string) -- callback to get rich text
    #      description of the item if it is intended to be dynamical.
    #      if not set, static description set via "set_items_callback" is
    #      used.
    #  "actions" : list<list> -- a list of actions to be offered
    #      via additional button next to Add/Edit/Delete button. Each item is
    #      a two-item-list, where the first item is the event ID and the second
    #      item is the label of the entry of the menu button. If there is only
    #      one entry, menu button is replaced by push button. If empty
    #      (or not specifued), nothing is shown.
    #  "title" : string -- the dialog title, must be specified
    #  "help" : string -- the help for the dialog, must be specifed
    #  "headers" : list<string> --  a list of the table headers, must be specified
    #  "next_button" : string -- label for the "Next" button. To hide it, set to
    #      nil. If not specified, "Next" is used.
    #  "back_button" : string -- label for the "Back" button. To hide it, set to
    #      nil. If not specified, "Back" is used.
    #  "abort_button" : string -- label for the "Abort" button. To hide it, set to
    #      nil. If not specified, "Abort" is used.
    #  ]
    # @return [Symbol] for wizard sequencer
    def RunHWDialog(settings)
      settings = deep_copy(settings)
      # reinitialize internal variables
      @current_items = []
      @descriptions = {}
      @last_event = {}

      # callbacks
      @action_callback = Convert.convert(
        Ops.get(settings, "action_callback"),
        from: "any",
        to:   "symbol (string, map)"
      )
      @get_item_descr_callback = Convert.convert(
        Ops.get(settings, "item_descr_callback"),
        from: "any",
        to:   "string (string)"
      )
      @set_items_callback = Convert.convert(
        Ops.get(settings, "set_items_callback"),
        from: "any",
        to:   "void ()"
      )
      @select_initial_item_callback = Convert.convert(
        Ops.get(settings, "set_initial_item_callback"),
        from: "any",
        to:   "void ()"
      )

      # other variables
      actions = Ops.get_list(settings, "actions", [])
      headers = Ops.get_list(settings, "headers", [])
      title = Ops.get_string(settings, "title", "")
      help = Ops.get_string(settings, "help", "HELP")

      # adapt the widget description map
      widget = CreateWidget(headers, actions)
      widget = Builtins.remove(widget, "handle_events")
      Ops.set(widget, "help", help)
      Ops.set(widget, "init", fun_ref(method(:Init), "void (string)"))
      Ops.set(
        widget,
        "handle",
        fun_ref(method(:Handle), "symbol (string, map)")
      )
      widget_descr = { "wizard_hw" => widget }

      # now run the dialog via CWM with handler set
      CWM.ShowAndRun(

        "widget_descr" => widget_descr,
        "widget_names" => ["wizard_hw"],
        "contents"     => VBox("wizard_hw"),
        "caption"      => title,
        "abort_button" => Ops.get_string(settings, "abort_button") do
          Label.AbortButton
        end,
        "back_button"  => Ops.get_string(settings, "back_button") do
          Label.BackButton
        end,
        "next_button"  => Ops.get_string(settings, "next_button") do
          Label.NextButton
        end

      )
    end

    # simple iface

    # Create the Hardware Wizard dialog
    # Draw the dialog
    # @note This is a stable API function
    # @param [String] title string the dialog title
    # @param [String] help string the help for the dialog
    # @param [Array<String>] headers a list of the table headers
    # @param [Array<Array>] actions a list of actions to be offered
    #      via additional button next to Add/Edit/Delete button. Each item is
    #      a two-item-list, where the first item is the event ID and the second
    #      item is the label of the entry of the menu button. If there is only
    #      one entry, menu button is replaced by push button. If empty
    #      (or not specifued), nothing is shown.
    #  below the widgets (next to other buttons)
    def CreateHWDialog(title, help, headers, actions)
      headers = deep_copy(headers)
      actions = deep_copy(actions)
      # reinitialize internal variables
      @current_items = []
      @descriptions = {}
      @last_event = {}
      @get_item_descr_callback = nil
      @action_callback = fun_ref(
        method(:SimpleStoreReturnValue),
        "symbol (string, map)"
      )

      # now create the dialog
      widget_descr = CreateWidget(headers, actions)
      Ops.set(widget_descr, "help", help) # to suppress error in log
      w = CWM.CreateWidgets(["wizard_hw"],  "wizard_hw" => widget_descr)
      contents = Ops.get_term(w, [0, "widget"], VBox())
      Wizard.SetContents(title, contents, help, false, true)

      nil
    end

    # Set which item is to be selected
    # @note This is a stable API function
    # @param [String] selected string the item that is should be marked as selected
    def SetSelectedItem(selected)
      _SetSelectedItem(selected)

      nil
    end

    # Return the id of the currently selected item in the table
    # @note This is a stable API function
    # @return id of the selected item
    def SelectedItem
      Convert.to_string(UI.QueryWidget(Id(:_hw_items), :CurrentItem))
    end

    # Set the rich text description.
    # @note This is a stable API function
    # @param [String] descr rich text description
    def SetRichDescription(descr)
      UI.ChangeWidget(Id(:_hw_sum), :Value, descr)

      nil
    end

    # Set the information about hardware
    # @note This is a stable API function
    # @param [Array<Hash{String => Object>}] items a list of maps, one item per item in the dialog, with keys
    #  "id" : string = the identification of the device,
    #  "rich_descr" : string = RichText description of the device
    #  "table_descr" : list<string> = fields of the table
    def SetContents(items)
      items = deep_copy(items)
      term_items = Builtins.maplist(items) do |i|
        t = Item(Id(Ops.get_string(i, "id", "")))
        Builtins.foreach(Ops.get_list(i, "table_descr", [])) do |l|
          t = Builtins.add(t, l)
        end
        deep_copy(t)
      end
      UI.ChangeWidget(Id(:_hw_items), :Items, term_items)
      StoreCurrentItems(items)
      enabled = Ops.greater_than(Builtins.size(items), 0)
      UI.ChangeWidget(Id(:edit), :Enabled, enabled)
      UI.ChangeWidget(Id(:delete), :Enabled, enabled)
      SetSelectedItem(Ops.get_string(items, [0, "id"], "")) if enabled

      nil
    end

    # Wait for event from the event
    # @note This is a stable API function
    # @return a map with keys:
    #  "event" : map = event as returned from UI::WaitForEvent (),
    #  "selected" : string = ID of the selected item in the list box
    def WaitForEvent
      event = nil
      while event.nil?
        event = UI.WaitForEvent
        event = nil if Handle("wizard_hw", event).nil?
      end
      deep_copy(@dialog_ret)
    end

    # Wait for event from the event
    # @note This is a stable API function
    # @return a map with keys:
    #  "event" : any = event as returned from UI::UserInoput ()
    #  "selected" : string = ID of the selected item in the list box
    def UserInput
      ret = WaitForEvent()
      Ops.set(ret, "event", Ops.get(ret, ["event", "ID"]))
      deep_copy(ret)
    end

    # Create rich text description of a device. It can be used for WizardHW::SetContents
    # function for formatting richtext device descriptions
    # @note This is a stable API function
    # @param [String] title header - usually device name
    # @param [Array<String>] properties important properties of the device which should be
    #		displayed in the overview dialog
    # @return [String] rich text string
    def CreateRichTextDescription(title, properties)
      properties = deep_copy(properties)
      items = ""

      if !properties.nil? && Ops.greater_than(Builtins.size(properties), 0)
        Builtins.foreach(properties) do |prop|
          items = Ops.add(Ops.add(Ops.add(items, "<LI>"), prop), "</LI>")
        end
      end

      ret = ""

      if !title.nil? && title != ""
        ret = Ops.add(Ops.add("<P><B>", title), "</B></P>")
      end

      if items != ""
        ret = Ops.add(Ops.add(Ops.add(ret, "<P><UL>"), items), "</UL></P>")
      end

      ret
    end

    # Get propertly list of an unconfigured device. Should be used together with
    # device name in CreateRichTextDescription() function.
    # @note This is a stable API function
    # @return a list of strings
    def UnconfiguredDevice
      # translators: message for hardware configuration without any configured
      # device
      [
        _("The device is not configured"),
        # translators: message for hardware configuration without any configured
        # device
        _("Press <B>Edit</B> to configure")
      ]
    end

    publish function: :CreateWidget, type: "map <string, any> (list <string>, list <list>)"
    publish function: :RunHWDialog, type: "symbol (map)"
    publish function: :CreateHWDialog, type: "void (string, string, list <string>, list <list>)"
    publish function: :SetSelectedItem, type: "void (string)"
    publish function: :SelectedItem, type: "string ()"
    publish function: :SetRichDescription, type: "void (string)"
    publish function: :SetContents, type: "void (list <map <string, any>>)"
    publish function: :WaitForEvent, type: "map <string, any> ()"
    publish function: :UserInput, type: "map <string, any> ()"
    publish function: :CreateRichTextDescription, type: "string (string, list <string>)"
    publish function: :UnconfiguredDevice, type: "list <string> ()"
  end

  WizardHW = WizardHWClass.new
  WizardHW.main
end
