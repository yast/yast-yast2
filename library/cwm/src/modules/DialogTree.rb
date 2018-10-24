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
# File:  modules/DialogTree.ycp
# Package:  Common widget manipulation
# Summary:  Routines for handling the dialog with tree on the left side
# Authors:  Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
require "yast"

module Yast
  class DialogTreeClass < Module
    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "CWM"
      Yast.import "Label"
      Yast.import "Wizard"

      # local data

      # Currently selected item in the tree
      @selected_screen = nil

      # Previously selected item in the tree
      @previous_screen = nil
    end

    # Restore the previously selected dialog after clicking another item not
    # causing dialog change due to validation failed
    def RestoreSelectedDialog
      @selected_screen = @previous_screen
      if UI.WidgetExists(Id(:wizardTree))
        UI.ChangeWidget(Id(:wizardTree), :CurrentItem, @selected_screen)
      else
        UI.WizardCommand(term(:SelectTreeItem, @selected_screen))
      end

      nil
    end

    # virtual DialogTree widget

    # Init function of virtual DialogTree widget
    # @param [String] key string widget key
    def DialogTreeInit(_key)
      if UI.WidgetExists(Id(:wizardTree))
        UI.ChangeWidget(Id(:wizardTree), :CurrentItem, @selected_screen)
        UI.SetFocus(Id(:wizardTree))
      else
        UI.WizardCommand(term(:SelectTreeItem, @selected_screen))
      end

      nil
    end

    # Handle function of virtual DialogTree widget
    # @param [String] key string widget key
    # @param [Hash] event map event that caused handler call
    # @return [Symbol] for wizard sequencer or nil
    def DialogTreeHandle(_key, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")

      ret = Convert.to_string(UI.QueryWidget(Id(:wizardTree), :CurrentItem)) if ret == :wizardTree
      @previous_screen = @selected_screen
      @selected_screen = Convert.to_string(ret)
      :_cwm_internal_tree_handle
    end

    # Get the map of the virtal left tree widget
    # @param [Array<String>] ids a list of widget ids of all tree items
    # @return [Hash] tree of the widget
    def GetVirtualDialogTreeWidget(ids)
      ids = deep_copy(ids)
      handle_events = deep_copy(ids)
      handle_events = Builtins.add(handle_events, :wizardTree)
      {
        "init"          => fun_ref(method(:DialogTreeInit), "void (string)"),
        "handle_events" => handle_events,
        "handle"        => fun_ref(
          method(:DialogTreeHandle),
          "symbol (string, map)"
        )
      }
    end

    # internal functions

    # Draw the screen related to the particular tree item
    # @param [Hash{String => Object}] current_screen a map describing the current screen
    # @param [Hash <String, Hash{String => Object>}] widget_descr a map describing all widgets that may be present in the
    #  screen
    # extra_widget a map of the additional widget to be added at the end
    #  of the list of widgets
    # @return a list of preprocessed widgets that appear in this dialog
    def DrawScreen(current_screen, widget_descr, extra_widget, set_focus)
      current_screen = deep_copy(current_screen)
      widget_descr = deep_copy(widget_descr)
      extra_widget = deep_copy(extra_widget)
      widget_names = Ops.get_list(current_screen, "widget_names", [])
      contents = Ops.get_term(current_screen, "contents", VBox())
      caption = Ops.get_string(current_screen, "caption", "")

      w = CWM.CreateWidgets(widget_names, widget_descr)
      help = CWM.MergeHelps(w)
      contents = CWM.PrepareDialog(contents, w)
      Wizard.SetContentsFocus(caption, contents, help, true, true, set_focus)

      # add virtual widget
      w = Builtins.add(w, extra_widget)

      # return widgets of the dialog for further usage
      deep_copy(w)
    end

    # Draw the dialog with the flat tree (only single level of the tree entries)
    # @param [Array<String>] ids_order a list of IDs in the same order as they are expected to be
    #  in the left menu
    # @param [Hash <String, Hash{String => Object>}] screens map of all screens (key is screen ID, value is screen
    #  description map
    def ShowFlat(ids_order, screens)
      ids_order = deep_copy(ids_order)
      screens = deep_copy(screens)
      Wizard.OpenTreeNextBackDialog
      tree = []
      Builtins.foreach(ids_order) do |i|
        tree = Wizard.AddTreeItem(
          tree,
          "",
          Ops.get_string(
            screens,
            [i, "tree_item_label"],
            Ops.get_string(screens, [i, "caption"], "")
          ),
          i
        )
      end
      Wizard.CreateTree(tree, "")

      nil
    end

    # Draw the dialog with multi-level tree
    # @param [list <map> ()] tree_handler a callback to a function that creates the tree using
    #  Wizard::AddTreeItem and returns the resulting tree
    def ShowTree(tree_handler)
      tree_handler = deep_copy(tree_handler)
      Wizard.OpenTreeNextBackDialog
      tree = tree_handler.call
      Wizard.CreateTree(tree, "")

      nil
    end

    # Adjust buttons at the bottom of the dialog
    # @param [Hash{String => String}] buttons a map with keys "abort_button", "back_button" and
    #  "next_button" adn values labels of appropriate buttons
    def AdjustButtons(buttons)
      buttons = deep_copy(buttons)
      CWM.AdjustButtons(
        Ops.get(buttons, "next_button") { Label.NextButton },
        Ops.get(buttons, "back_button") { Label.BackButton },
        Ops.get(buttons, "abort_button") { Label.AbortButton },
        Label.HelpButton
      )

      nil
    end

    # Adjust buttons at the bottom of the dialog
    # @param [Hash{String => Object}] buttons a map with keys "abort_button", "back_button" and
    #  "next_button" adn values labels of appropriate buttons, other keys
    #  with values of other types are possible
    def AdjustButtonsAny(buttons)
      buttons = deep_copy(buttons)
      buttons2 = Convert.convert(
        Builtins.filter(buttons) { |k, _v| Builtins.issubstring(k, "_button") },
        from: "map <string, any>",
        to:   "map <string, string>"
      )
      AdjustButtons(buttons2)

      nil
    end

    # Generic function to create dialog and handle it's events.
    # Run the event loop over the dialog with the left tree.
    # @param setttings a map of settings of the dialog
    # <pre>
    # "screens" : map<string,map<string,any>> of all screens
    #             (key is screen ID, value is screen description map)
    # "widget_descr" : map<string,map<string,any>> description map of all widgets
    # "initial_screen" : string the id of the screen that should be displayed
    #                    as the first
    # "fallback" : map<any,any> initialize/save/handle fallbacks if not specified
    #              with the widgets, to be passed to CWM
    # </pre>
    # @return [Symbol] wizard sequencer symbol
    def Run(settings)
      settings = deep_copy(settings)
      screens = Ops.get_map(settings, "screens", {})
      widget_descr = Ops.get_map(settings, "widget_descr", {})
      initial_screen = Ops.get_string(settings, "initial_screen", "")
      functions = Ops.get_map(settings, "functions", {})

      initial_screen = "" if initial_screen.nil?
      if initial_screen == ""
        Builtins.foreach(screens) do |k, _v|
          initial_screen = k if initial_screen == ""
        end
      end

      @selected_screen = initial_screen
      ids = Builtins.maplist(screens) { |k, _v| k }
      extra_widget = GetVirtualDialogTreeWidget(ids)

      w = DrawScreen(
        Ops.get(screens, @selected_screen, {}),
        widget_descr,
        extra_widget,
        true
      )

      ret = nil
      while ret.nil?
        CWM.SetValidationFailedHandler(
          fun_ref(method(:RestoreSelectedDialog), "void ()")
        )
        ret = CWM.Run(w, functions)
        CWM.SetValidationFailedHandler(nil)
        # switching scrren, dialog was validated and stored
        next if ret != :_cwm_internal_tree_handle

        toEval = Convert.convert(
          Ops.get(screens, [@selected_screen, "init"]),
          from: "any",
          to:   "symbol (string)"
        )
        tab_init = nil
        tab_init = toEval.call(@selected_screen) if !toEval.nil?
        if tab_init.nil? # everything OK
          w = DrawScreen(
            Ops.get(screens, @selected_screen, {}),
            widget_descr,
            extra_widget,
            false
          )
          ret = nil
        elsif tab_init == :refuse_display # do not display this screen
          @selected_screen = @previous_screen
          ret = nil # exit dialog
        else
          ret = tab_init
        end
      end
      ret
    end

    # Run the event loop over the dialog with the left tree. After finished, run
    #  UI::CloseDialog
    # @param setttings a map of settings of the dialog. See @Run for possible keys
    # @return [Symbol] wizard sequencer symbol
    def RunAndHide(settings)
      settings = deep_copy(settings)
      Run(settings)
    ensure
      UI.CloseDialog
    end

    # Display the dialog and run its event loop
    # @param setttings a map of settings of the dialog
    # <pre>
    # "ids_order" : list<string> of IDs in the same order as they are expected
    #               to be in the left menu. Not used if "tree_creator" is defined
    # "tree_creator" : list<map>() a callback to a function that creates
    #                  the tree using Wizard::AddTreeItem and returns the
    #                  resulting tree
    # "back_button" : string label of the back button (optional)
    # "next_button" : string label of the next button (optional)
    # "abort_button" : string label of the abort button (optional)
    # See @RunAndHide for other possible keys in the map
    # </pre>
    # @return [Symbol] wizard sequencer symbol
    def ShowAndRun(settings)
      settings = deep_copy(settings)
      ids_order = Ops.get_list(settings, "ids_order", [])
      screens = Ops.get_map(settings, "screens", {})
      tree_handler = Convert.convert(
        Ops.get(settings, "tree_creator"),
        from: "any",
        to:   "list <map> ()"
      )

      if !tree_handler.nil?
        ShowTree(tree_handler)
      else
        ShowFlat(ids_order, screens)
        if Ops.get_string(settings, "initial_screen", "") == ""
          Builtins.find(ids_order) do |s|
            Ops.set(settings, "initial_screen", s)
            true
          end
        end
      end
      AdjustButtonsAny(settings)
      RunAndHide(settings)
    end

    publish function: :ShowFlat, type: "void (list <string>, map <string, map <string, any>>)"
    publish function: :ShowTree, type: "void (list <map> ())"
    publish function: :AdjustButtons, type: "void (map <string, string>)"
    publish function: :AdjustButtonsAny, type: "void (map <string, any>)"
    publish function: :Run, type: "symbol (map <string, any>)"
    publish function: :RunAndHide, type: "symbol (map <string, any>)"
    publish function: :ShowAndRun, type: "symbol (map <string, any>)"
  end

  DialogTree = DialogTreeClass.new
  DialogTree.main
end
