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
# File:	modules/CWMTab.ycp
# Package:	Common widget manipulation
# Summary:	Routines for tab widget handling
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
require "yast"

module Yast
  class CWMTabClass < Module
    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "CWM"
      Yast.import "Wizard"

      # local constants

      # Empty tab (just to be used as fallback constant)
      @empty_tab = VBox(VStretch(), HStretch())

      # Fallback label for a tab if no is defined
      @default_tab_header = _("Tab")

      # local variables - remember to add them to Push+Pop

      # ID of the currently displayed tab
      @current_tab_id = nil

      # ID of previously selected tab
      @previous_tab_id = nil

      # description map of the currently selected tab
      @current_tab_map = {}

      # description map of the currently selected tab
      @previous_tab_map = {}

      # this one is expressly excluded from Push+Pop
      @last_tab_id = nil

      # nesting stack, needed because of bnc#406138
      @stack = []
    end

    def Push
      tos = {
        "cti" => @current_tab_id,
        "pti" => @previous_tab_id,
        "ctm" => @current_tab_map,
        "ptm" => @previous_tab_map
      }
      @stack = Builtins.prepend(@stack, tos)

      nil
    end

    def Pop
      tos = Ops.get(@stack, 0, {})
      @current_tab_id = Ops.get_string(tos, "cti", "")
      @previous_tab_id = Ops.get_string(tos, "pti", "")
      @current_tab_map = Ops.get_map(tos, "ctm", {})
      @previous_tab_map = Ops.get_map(tos, "ptm", {})
      Ops.set(@stack, 0, nil)
      @stack = Builtins.filter(@stack) { |m| !m.nil? }

      nil
    end

    # local functions

    # Initialize the widgets in the tab
    # @param [Hash{String => Object}] tab a map describing the tab
    def TabInit(tab)
      tab = deep_copy(tab)
      widgets = Ops.get_list(tab, "widgets", [])
      CWM.initWidgets(widgets)

      nil
    end

    # Clean up the widgets in the tab
    # @param [Hash{String => Object}] tab a map describing the tab
    def TabCleanup(tab)
      tab = deep_copy(tab)
      widgets = Ops.get_list(tab, "widgets", [])
      CWM.cleanupWidgets(widgets)

      nil
    end

    # Handle events on the widgets inside the tab
    # @param [Hash{String => Object}] tab a map describing the tab
    # @param [Hash] event map event that caused the event handling
    # @return [Symbol] for wizard sequencer or nil
    def TabHandle(tab, event)
      tab = deep_copy(tab)
      event = deep_copy(event)
      widgets = Ops.get_list(tab, "widgets", [])
      CWM.handleWidgets(widgets, event)
    end

    # Store settings of all widgets inside the tab
    # @param [Hash{String => Object}] tab a map describing the tab
    # @param [Hash] event map event that caused the saving process
    def TabStore(tab, event)
      tab = deep_copy(tab)
      event = deep_copy(event)
      widgets = Ops.get_list(tab, "widgets", [])
      CWM.saveWidgets(widgets, event)
    end

    # Validate settings of all widgets inside the tab
    # @param [Hash{String => Object}] tab a map describing the tab
    # @param [Hash] event map event that caused the validation process
    # @return [Boolean] true if validation succeeded
    def TabValidate(tab, event)
      tab = deep_copy(tab)
      event = deep_copy(event)
      widgets = Ops.get_list(tab, "widgets", [])
      CWM.validateWidgets(widgets, event)
    end

    # Redraw the whole tab
    # @param [Hash{String => Object}] tab a map describing the tab
    def RedrawTab(tab)
      tab = deep_copy(tab)
      contents = Ops.get_term(tab, "contents", @empty_tab)
      UI.ReplaceWidget(:_cwm_tab_contents_rp, contents)

      nil
    end

    # Redraw the part of the help related to the tab widget
    # @param [Hash{String => Object}] widget a map of the tab widget
    # @param [Hash{String => Object}] tab a map describing the tab
    def RedrawHelp(widget, tab)
      widget = deep_copy(widget)
      tab = deep_copy(tab)
      help = Ops.add(
        Ops.get_string(widget, "tab_help", ""),
        Ops.get_string(tab, "help", "")
      )
      CWM.ReplaceWidgetHelp(Ops.get_string(widget, "_cwm_key", ""), help)

      nil
    end

    # Make the currently selected tab be displayed a separate way
    def MarkCurrentTab
      if UI.HasSpecialWidget(:DumbTab)
        UI.ChangeWidget(Id(:_cwm_tab), :CurrentItem, @current_tab_id)
      else
        if !@previous_tab_id.nil?
          UI.ChangeWidget(
            Id(@previous_tab_id),
            :Label,
            Ops.get_string(@previous_tab_map, "header", @default_tab_header)
          )
        end
        UI.ChangeWidget(
          Id(@current_tab_id),
          :Label,
          Ops.add(
            Ops.add(UI.Glyph(:BulletArrowRight), "  "),
            Ops.get_string(@current_tab_map, "header", @default_tab_header)
          )
        )
      end

      nil
    end

    # Switch to a new tab
    # @param new_tab_it id of the new tab
    # @param [Hash{String => Object}] widget tab set description
    def InitNewTab(new_tab_id, widget)
      widget = deep_copy(widget)
      @previous_tab_id = @current_tab_id
      @previous_tab_map = deep_copy(@current_tab_map)
      @current_tab_id = new_tab_id
      @current_tab_map = Ops.get_map(widget, ["tabs", @current_tab_id], {})
      MarkCurrentTab()
      RedrawTab(@current_tab_map)
      RedrawHelp(widget, @current_tab_map)
      TabInit(@current_tab_map)
      # allow a handler to enabled/disable widgets before the first real
      # UserInput takes place
      UI.FakeUserInput( "ID" => "_cwm_tab_wakeup" )

      nil
    end

    # public functions

    # Init function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    def Init(widget, _key)
      widget = deep_copy(widget)
      Push()
      InitNewTab(Ops.get_string(widget, "initial_tab", ""), widget)

      nil
    end

    # Clean up function of the widget
    # @param [String] key the widget key (ignored)
    def CleanUp(_key)
      TabCleanup(@current_tab_map)
      @last_tab_id = @current_tab_id
      Pop()

      nil
    end

    # Handle function of the widget
    # @param [Hash{String => Object}] widget a widget description map
    # @param [String] key strnig the widget key
    # @param [Hash] event map event to be handled
    # @return [Symbol] for wizard sequencer or nil
    def Handle(widget, _key, event)
      widget = deep_copy(widget)
      event = deep_copy(event)
      all_tabs = Ops.get_list(widget, "tabs_list", [])
      h_ret = TabHandle(@current_tab_map, event)
      return h_ret if !h_ret.nil?
      ret = Ops.get(event, "ID")
      if Ops.is_string?(ret) &&
          Builtins.contains(all_tabs, Convert.to_string(ret)) &&
          # At initialization, qt thinks it has switched to the same tab
          # So prevent unnecessary double initialization
          ret != @current_tab_id
        if !TabValidate(@current_tab_map, event)
          MarkCurrentTab()
          return nil
        end
        TabStore(@current_tab_map, event)

        InitNewTab(Convert.to_string(ret), widget)
      end
      nil
    end

    # Store function of the widget
    # @param [String] key strnig the widget key
    # @param [Hash] event map that caused widget data storing
    def Store(_key, event)
      event = deep_copy(event)
      TabStore(@current_tab_map, event)

      nil
    end

    # Init function of the widget
    # @param [String] key strnig the widget key
    def InitWrapper(key)
      Init(CWM.GetProcessedWidget, key)

      nil
    end

    # Get the ID of the currently displayed tab
    # @return [String] the ID of the currently displayed tab
    def CurrentTab
      @current_tab_id
    end

    # Get the ID of the last displayed tab (after CWM::Run is done).
    # It is needed because of bnc#134386.
    # @return [String] the ID of the last displayed tab
    def LastTab
      @last_tab_id
    end

    # A hook to handle Alt-Ctrl-Shift-D
    def handleDebug
      Builtins.y2debug("Handling a debugging event")

      nil
    end

    # Handle function of the widget
    # @param map widget a widget description map
    # @param [String] key strnig the widget key
    # @param [Hash] event map event to be handled
    # @return [Symbol] for wizard sequencer or nil
    def HandleWrapper(key, event)
      event = deep_copy(event)
      handleDebug if Ops.get_string(event, "EventType", "") == "DebugEvent"
      Handle(CWM.GetProcessedWidget, key, event)
    end

    # Validate function of the widget
    # @param [String] key strnig the widget key
    # @param [Hash] event map that caused widget data storing
    def Validate(_key, event)
      event = deep_copy(event)
      TabValidate(@current_tab_map, event)
    end

    # Get the widget description map
    # @param tab_order a list of the IDs of the tabs
    # @param tabs a map of all tabs (key is tab ID, value is a map describing
    #  the tab
    # @param initial_tab string the tab tha will be displayed as the first
    # @param widget_descr description map of all widgets that are present
    #  in any of the tabs
    # @param tab_help strign general help to the tab widget
    # @return [Hash] the widget description map
    def CreateWidget(settings)
      settings = deep_copy(settings)
      tab_order = Ops.get_list(settings, "tab_order", [])
      tabs = Ops.get_map(settings, "tabs", {})
      initial_tab = Ops.get_string(settings, "initial_tab", "")
      widget_descr = Ops.get_map(settings, "widget_descr", {})
      tab_help = Ops.get_string(settings, "tab_help", "")

      widget = nil
      rp = ReplacePoint(Id(:_cwm_tab_contents_rp), @empty_tab)

      # widget
      if UI.HasSpecialWidget(:DumbTab)
        panes = Builtins.maplist(tab_order) do |t|
          label = Ops.get_string(tabs, [t, "header"], @default_tab_header)
          Item(Id(t), label, t == initial_tab)
        end
        widget = DumbTab(Id(:_cwm_tab), panes, rp)
      else
        tabbar = HBox()
        Builtins.foreach(tab_order) do |t|
          label = Ops.get_string(tabs, [t, "header"], @default_tab_header)
          tabbar = Builtins.add(tabbar, PushButton(Id(t), label))
        end
        widget = VBox(Left(tabbar), Frame("", rp))
      end

      tabs = Builtins.mapmap(tabs) do |k, v|
        contents = Ops.get_term(v, "contents", VBox())
        widget_names = Convert.convert(
          Ops.get(v, "widget_names") { CWM.StringsOfTerm(contents) },
          from: "any",
          to:   "list <string>"
        )
        # second arg wins
        fallback = Builtins.union(
          Ops.get_map(settings, "fallback_functions", {}),
          Ops.get_map(v, "fallback_functions", {})
        )
        w = CWM.CreateWidgets(widget_names, widget_descr)
        w = CWM.mergeFunctions(w, fallback)
        help = CWM.MergeHelps(w)
        contents = CWM.PrepareDialog(contents, w)
        Ops.set(v, "widgets", w)
        Ops.set(v, "help", help)
        Ops.set(v, "contents", contents)
        { k => v }
      end

      {
        "widget"            => :custom,
        "custom_widget"     => widget,
        "init"              => fun_ref(method(:InitWrapper), "void (string)"),
        "store"             => fun_ref(method(:Store), "void (string, map)"),
        "clean_up"          => fun_ref(method(:CleanUp), "void (string)"),
        "handle"            => fun_ref(
          method(:HandleWrapper),
          "symbol (string, map)"
        ),
        "validate_type"     => :function,
        "validate_function" => fun_ref(
          method(:Validate),
          "boolean (string, map)"
        ),
        "initial_tab"       => initial_tab,
        "tabs"              => tabs,
        "tabs_list"         => tab_order,
        "tab_help"          => tab_help,
        "no_help"           => true
      }
    end

    publish function: :Init, type: "void (map <string, any>, string)"
    publish function: :CleanUp, type: "void (string)"
    publish function: :Handle, type: "symbol (map <string, any>, string, map)"
    publish function: :Store, type: "void (string, map)"
    publish function: :InitWrapper, type: "void (string)"
    publish function: :CurrentTab, type: "string ()"
    publish function: :LastTab, type: "string ()"
    publish function: :HandleWrapper, type: "symbol (string, map)"
    publish function: :Validate, type: "boolean (string, map)"
    publish function: :CreateWidget, type: "map <string, any> (map)"
  end

  CWMTab = CWMTabClass.new
  CWMTab.main
end
