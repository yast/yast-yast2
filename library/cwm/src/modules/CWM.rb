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
# File:	modules/CWM.ycp
# Package:	Common widget manipulation
# Summary:	Routines for common widget manipulation
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
require "yast"

require "cwm/widget"

module Yast
  class CWMClass < Module
    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "Label"
      Yast.import "Report"
      Yast.import "Wizard"

      # local variables

      # Widget that is being currently processed
      @processed_widget = {}

      # All widgets of the current dialog, in the correct order
      @current_dialog_widgets = []

      # stack of settings of nested calls of CWM
      @settings_stack = []

      # Handler to be called after validation of a dialog fails
      @validation_failed_handler = nil

      # UI containers, layout helpers that contain other widgets.  Used by
      # functions that recurse through "contents" to decide whether to go
      # deeper.
      @ContainerWidgets = [
        :Frame,
        :RadioButtonGroup,
        :VBox,
        :HBox,
        :MarginBox,
        :MinWidth,
        :MinHeight,
        :MinSize,
        :Left,
        :Right,
        :Top,
        :Bottom,
        :HCenter,
        :VCenter,
        :HVCenter,
        :HSquash,
        :VSquash,
        :HVSquash,
        :HWeight,
        :VWeight
      ]
    end

    # local functions

    # Push the settings of the currently run dialog to the stack
    def PushSettings
      @settings_stack = Builtins.prepend(
        @settings_stack,
        "widgets" => @current_dialog_widgets
      )

      nil
    end

    # Pop the settings of the currently run dialog from the stack
    def PopSettings
      current_dialog = Ops.get(@settings_stack, 0, {})
      Ops.set(@settings_stack, 0, nil)
      @settings_stack = Builtins.filter(@settings_stack) { |e| !e.nil? }
      @current_dialog_widgets = Ops.get_list(current_dialog, "widgets", [])

      nil
    end

    # Process term with the dialog, replace strings in the term with
    # appropriate widgets
    # @param [Yast::Term] t term dialog containing strings
    # @param [Hash <String, Hash{String => Object>}] widgets map of widget name -> widget description map
    # @return [Yast::Term] updated term ready to be used as a dialog
    def ProcessTerm(t, widgets)
      t = deep_copy(t)
      widgets = deep_copy(widgets)
      args = Builtins.size(t)
      return deep_copy(t) if args == 0
      ret = Builtins.toterm(
        Builtins.substring(Builtins.sformat("%1", Builtins.symbolof(t)), 1)
      )
      id_frame = false
      index = 0
      current = Builtins.symbolof(t)
      while Ops.less_than(index, args)
        arg = Ops.get(t, index)
        # FIXME: still there is a problem for frames without label
        if current == :Frame && index == 0 # no action
          # frame can have id and also label, so mark if id is used
          id_frame = true if arg.is_a?(Yast::Term) && arg.value == :id
          Builtins.y2debug("Leaving untouched %1", arg)
        elsif current == :Frame && index == 1 && id_frame && arg.is_a?(::String) # no action
          id_frame = false
          Builtins.y2debug("Leaving untouched %1", arg)
        elsif Ops.is_term?(arg) && !arg.nil? # recurse
          s = Builtins.symbolof(Convert.to_term(arg))
          if Builtins.contains(@ContainerWidgets, s)
            arg = ProcessTerm(Convert.to_term(arg), widgets)
          end
        elsif Ops.is_string?(arg) # action
          arg = Ops.get_term(
            widgets,
            [Convert.to_string(arg), "widget"],
            VBox()
          )
          s = Builtins.symbolof(arg)
          if Builtins.contains(@ContainerWidgets, s)
            arg = ProcessTerm(arg, widgets)
          end
        end
        ret = Builtins.add(ret, arg)
        index = Ops.add(index, 1)
      end
      deep_copy(ret)
    end

    # Process term with the dialog, return all strings.
    # To be used as an argument for widget_names until they are obsoleted.
    # @param [Yast::Term] t term dialog containing strings
    # @return [String]s found in the term
    def StringsOfTerm(t)
      t = deep_copy(t)
      rets = []
      args = Builtins.size(t)
      index = 0
      while Ops.less_than(index, args)
        arg = Ops.get(t, index)
        current = Builtins.symbolof(t)
        if current == :Frame && index == 0 # no action
          Builtins.y2debug("Leaving untouched %1", arg)
        elsif Ops.is_term?(arg) && !arg.nil? # recurse
          s = Builtins.symbolof(Convert.to_term(arg))
          if Builtins.contains(@ContainerWidgets, s)
            rets = Ops.add(rets, StringsOfTerm(Convert.to_term(arg)))
          end
        elsif Ops.is_string?(arg) # action
          rets = Builtins.add(rets, Convert.to_string(arg))
        end
        index = Ops.add(index, 1)
      end
      deep_copy(rets)
    end

    # Validate the value against the basic type
    # @param [Object] value any a value to validate
    # @param [String] type string type information
    # @return [Boolean] true on success or if do not know how to validate
    def ValidateBasicType(value, type)
      value = deep_copy(value)
      return Ops.is_term?(value) if type == "term"
      return Ops.is_string?(value) if type == "string"
      return Ops.is_symbol?(value) if type == "symbol"
      return Ops.is_list?(value) if type == "list"
      return Ops.is_map?(value) if type == "map"
      return Ops.is_boolean?(value) if type == "boolean"
      return Ops.is_integer?(value) if type == "integer"

      Builtins.y2error("Unknown value type %1", type)
      true
    end

    # Validate type of entry of the widget/option description map
    # Also checks option description maps if present
    # @param [String] key string key of the map entry
    # @param [Object] value any value of the map entry
    # @param [String] widget any name of the widget/option
    # @return [Boolean] true if validation succeeded
    def ValidateValueType(key, value, widget)
      value = deep_copy(value)
      types = {
        # general
        "widget"        => "symbol",
        "custom_widget" => "term",
        "handle_events" => "list",
        "help"          => "string",
        "label"         => "string",
        "opt"           => "list",
        "ui_timeout"    => "integer",
        "validate_type" => "symbol",
        # int field
        "minimum"       => "integer",
        "maximum"       => "integer",
        "_cwm_attrib"   => "map",
        "fallback"      => "map"
      }
      type = Ops.get(types, key)
      success = true
      if type.nil?
        if key == "widget_func"
          success = Ops.is(value, "term ()")
        elsif key == "init"
          success = Ops.is(value, "void (string)")
        elsif key == "handle"
          success = Ops.is(value, "symbol (string, map)")
        elsif key == "store"
          success = Ops.is(value, "void (string, map)")
        elsif key == "cleanup"
          success = Ops.is(value, "void (string)")
        elsif key == "validate_function"
          success = Ops.is(value, "boolean (string, map)")
        elsif key == "items"
          success = Ops.is(value, "list <list <string>>")
        elsif key == "_cwm_do_validate"
          success = Ops.is(value, "boolean (string, map <string, any>)")
        end
      else
        success = ValidateBasicType(value, type)
      end

      if !success
        Builtins.y2error(
          "Wrong type of option %1 in description map of %2",
          key,
          widget
        )
      end

      success
    end

    # Validate value of entry of the widget/option description map
    # Also checks option description maps if present
    # @param [String] key string key of the map entry
    # @param [Object] value any value of the map entry
    # @param [String] widget any name of the widget/option
    # @return [Boolean] true if validation succeeded
    def ValidateValueContents(key, value, widget)
      value = deep_copy(value)
      error = ""
      if key == "label"
        s = Convert.to_string(value)
        if s.nil? || Builtins.size(s) == 0
          error = "Empty label"
        elsif Builtins.size(Builtins.filterchars(s, "&")) != 1
          error = "Label has no shortcut or more than 1 shortcuts"
        end
      elsif key == "help"
        s = Convert.to_string(value)
        error = "Empty help" if s.nil?
      elsif key == "widget"
        s = Convert.to_symbol(value)
        error = "No widget specified" if s.nil?
      elsif key == "custom_widget"
        s = Convert.to_term(value)
        error = "No custom widget specified" if s.nil?
      end

      return true if error == ""

      Builtins.y2error("Error on key %1 of widget %2: %3", key, widget, error)
      false
    end

    def GetLowestTimeout(widgets)
      widgets = deep_copy(widgets)
      minimum = 0
      Builtins.foreach(widgets) do |w|
        timeout = Ops.get_integer(w, "ui_timeout", 0)
        if Ops.less_than(timeout, minimum) && Ops.greater_than(timeout, 0) ||
            minimum == 0
          minimum = timeout
        end
      end
      minimum
    end

    # Add fallback functions to a widget
    # global only because of testsuites
    # @param [Array<Hash{String => Object>}] widgets a list of widget desctiption maps
    # @param [Hash] functions map of functions
    # @return a list of modified widget description maps
    def mergeFunctions(widgets, functions)
      widgets = deep_copy(widgets)
      functions = deep_copy(functions)
      functions = Builtins.filter(functions) { |k, _v| Ops.is_string?(k) }
      fallback_functions = Convert.convert(
        functions,
        from: "map",
        to:   "map <string, any>"
      )
      Builtins.maplist(widgets) do |w|
        Convert.convert(
          Builtins.union(fallback_functions, w),
          from: "map",
          to:   "map <string, any>"
        )
      end
    end

    # Set widgets according to internally stored settings
    # global only because of testsuites
    # @param [Array<Hash{String => Object>}] widgets list of maps representing widgets
    def initWidgets(widgets)
      widgets = deep_copy(widgets)
      Builtins.foreach(widgets) do |w|
        # set initial properties
        valid_chars = Ops.get_string(w, "valid_chars")
        if !valid_chars.nil?
          UI.ChangeWidget(
            Id(Ops.get_string(w, "_cwm_key", "")),
            :ValidChars,
            valid_chars
          )
        end
        # set initial values
        @processed_widget = deep_copy(w)
        toEval = Convert.convert(
          Ops.get(w, "init"),
          from: "any",
          to:   "void (string)"
        )
        toEval.call(Ops.get_string(w, "_cwm_key", "")) if !toEval.nil?
      end

      nil
    end

    # Handle change of widget after event generated
    # global only because of testsuites
    # @param [Array<Hash{String => Object>}] widgets list of maps represenging widgets
    # @param [Hash] event_descr map event that occured
    # @return [Symbol] modified action (sometimes may be needed) or nil
    def handleWidgets(widgets, event_descr)
      widgets = deep_copy(widgets)
      event_descr = deep_copy(event_descr)
      ret = nil
      Builtins.foreach(widgets) do |w|
        if ret.nil?
          @processed_widget = deep_copy(w)
          events = Ops.get_list(w, "handle_events", [])
          toEval = Convert.convert(
            Ops.get(w, "handle"),
            from: "any",
            to:   "symbol (string, map)"
          )
          if !toEval.nil? &&
              (events == [] ||
                Builtins.contains(events, Ops.get(event_descr, "ID")))
            ret = toEval.call(Ops.get_string(w, "_cwm_key", ""), event_descr)
          end
        end
      end
      ret
    end

    # Save changes of widget after event generated
    # global only because of testsuites
    # CWMTab uses it too
    # @param [Array<Hash{String => Object>}] widgets list of maps represenging widgets
    # @param [Hash] event map event that occured
    def saveWidgets(widgets, event)
      widgets = deep_copy(widgets)
      event = deep_copy(event)
      Builtins.foreach(widgets) do |w|
        @processed_widget = deep_copy(w)
        toEval = Convert.convert(
          Ops.get(w, "store"),
          from: "any",
          to:   "void (string, map)"
        )
        toEval.call(Ops.get_string(w, "_cwm_key", ""), event) if !toEval.nil?
      end

      nil
    end

    # Cleanup after dialog was finished (independently on what event)
    # global only because of testsuites
    # @param [Array<Hash{String => Object>}] widgets list of maps represenging widgets
    def cleanupWidgets(widgets)
      widgets = deep_copy(widgets)
      Builtins.foreach(widgets) do |w|
        @processed_widget = deep_copy(w)
        toEval = Convert.convert(
          Ops.get(w, "cleanup"),
          from: "any",
          to:   "void (string)"
        )
        toEval.call(Ops.get_string(w, "_cwm_key", "")) if !toEval.nil?
      end

      nil
    end

    # functions

    # Return description map of currently processed widget
    # @return [Hash] description map of currently processed widget
    def GetProcessedWidget
      deep_copy(@processed_widget)
    end

    # Create a term with OK and Cancel buttons placed horizontally
    # @return the term (HBox)
    def OkCancelBox
      ButtonBox(
        PushButton(
          Id(:_tp_ok),
          Opt(:key_F10, :default, :okButton),
          Label.OKButton
        ),
        PushButton(
          Id(:_tp_cancel),
          Opt(:key_F9, :cancelButton),
          Label.CancelButton
        )
      )
    end

    # Validate widget description map, check for maps structure
    # Also checks option description maps if present
    # @param [Hash <String, Hash{String => Object>}] widgets map widgets description map
    # @return [Boolean] true on success
    def ValidateMaps(widgets)
      widgets = deep_copy(widgets)
      ret = true
      Builtins.foreach(widgets) do |k, v|
        Builtins.foreach(v) do |kk, vv|
          ret = ValidateValueType(kk, vv, k) && ret
        end
        to_check = []
        if Ops.get(v, "widget") == :custom
          to_check = ["custom_widget"]
        elsif Ops.get(v, "widget") == :empty
          to_check = []
        else
          to_check = ["label", "widget"]
        end
        if !Builtins.haskey(v, "no_help")
          to_check = Convert.convert(
            Builtins.merge(to_check, ["help"]),
            from: "list",
            to:   "list <string>"
          )
        end
        Builtins.foreach(to_check) do |key|
          if key != "label" ||
              Ops.get(v, "widget") != :radio_buttons &&
                  Ops.get(v, "widget") != :custom &&
                  Ops.get(v, "widget") != :rich_text &&
                  Ops.get(v, "widget") != :func
            ret = ValidateValueContents(key, Ops.get(v, key), k) && ret
          end
        end
        if Ops.get(v, "widget") == :custom
          ret = ValidateValueContents(
            "custom_widget",
            Ops.get(v, "custom_widget"),
            k
          ) && ret
        end
        # validate widget-specific entries
        if Builtins.haskey(v, "_cwm_do_validate")
          val_func = Convert.convert(
            Ops.get(v, "_cwm_do_validate"),
            from: "any",
            to:   "boolean (string, map <string, any>)"
          )
          ret = val_func.call(k, v) && ret if !val_func.nil?
        end
      end
      ret
    end

    # Prepare a widget for usage
    # @param [Hash{String => Object}] widget_descr map widget description map
    # @return [Hash] modified widget description map
    def prepareWidget(widget_descr)
      widget_descr = deep_copy(widget_descr)
      w = deep_copy(widget_descr)
      widget = Ops.get_symbol(w, "widget", :inputfield)

      if Ops.get(w, "widget") == :empty
        Ops.set(w, "widget", VBox())
      elsif Ops.get(w, "widget") == :custom &&
          Ops.get(w, "custom_widget")
        Ops.set(w, "widget", Ops.get_term(w, "custom_widget") { VSpacing(0) })
      elsif Ops.get(w, "widget") == :func
        toEval = Convert.convert(
          Ops.get(w, "widget_func"),
          from: "any",
          to:   "term ()"
        )
        if !toEval.nil?
          Ops.set(w, "widget", toEval.call)
        else
          Ops.set(w, "widget", VBox())
        end
      else
        id_term = Id(Ops.get_string(w, "_cwm_key", ""))
        opt_term = Opt()
        Builtins.foreach(Ops.get_list(w, "opt", [])) do |o|
          opt_term = Builtins.add(opt_term, o)
        end
        label = Ops.get_string(w, "label", Ops.get_string(w, "_cwm_key", ""))

        if widget == :inputfield || widget == :textentry
          # backward compatibility
          if !Builtins.contains(Builtins.argsof(opt_term), :hstretch)
            opt_term = Builtins.add(opt_term, :hstretch)
          end
          Ops.set(w, "widget", InputField(id_term, opt_term, label))
        elsif widget == :password
          Ops.set(w, "widget", Password(id_term, opt_term, label))
        elsif widget == :checkbox
          Ops.set(w, "widget", CheckBox(id_term, opt_term, label))
        elsif widget == :combobox
          Ops.set(
            w,
            "widget",
            ComboBox(
              id_term,
              opt_term,
              label,
              Builtins.maplist(Ops.get_list(w, "items", [])) do |i|
                Item(Id(Ops.get(i, 0, "")), Ops.get(i, 1, Ops.get(i, 0, "")))
              end
            )
          )
        elsif widget == :selection_box
          Ops.set(
            w,
            "widget",
            SelectionBox(
              id_term,
              opt_term,
              label,
              Builtins.maplist(Ops.get_list(w, "items", [])) do |i|
                Item(Id(Ops.get(i, 0, "")), Ops.get(i, 1, Ops.get(i, 0, "")))
              end
            )
          )
        elsif widget == :multi_selection_box
          Ops.set(
            w,
            "widget",
            MultiSelectionBox(
              id_term,
              opt_term,
              label,
              Builtins.maplist(Ops.get_list(w, "items", [])) do |i|
                Item(Id(Ops.get(i, 0, "")), Ops.get(i, 1, Ops.get(i, 0, "")))
              end
            )
          )
        elsif widget == :intfield
          min = Ops.get_integer(w, "minimum", 0)
          max = Ops.get_integer(w, "maximum", 2**31 - 1) # libyui support only signed int
          Ops.set(
            w,
            "widget",
            IntField(id_term, opt_term, label, min, max, min)
          )
        elsif widget == :radio_buttons
          hspacing = Ops.get_integer(w, "hspacing", 0)
          vspacing = Ops.get_integer(w, "vspacing", 0)
          buttons = VBox(VSpacing(vspacing))
          Builtins.foreach(Ops.get_list(w, "items", [])) do |i|
            buttons = Builtins.add(
              buttons,
              Left(
                RadioButton(
                  Id(Ops.get(i, 0, "")),
                  opt_term,
                  Ops.get(i, 1, Ops.get(i, 0, ""))
                )
              )
            )
            buttons = Builtins.add(buttons, VSpacing(vspacing))
          end
          Ops.set(
            w,
            "widget",
            Frame(
              label,
              HBox(
                HSpacing(hspacing),
                RadioButtonGroup(id_term, buttons),
                HSpacing(hspacing)
              )
            )
          )
        elsif widget == :radio_button
          Ops.set(w, "widget", RadioButton(id_term, opt_term, label))
        elsif widget == :push_button
          Ops.set(w, "widget", PushButton(id_term, opt_term, label))
        elsif widget == :menu_button
          Ops.set(
            w,
            "widget",
            MenuButton(
              id_term,
              opt_term,
              label,
              Builtins.maplist(Ops.get_list(w, "items", [])) do |i|
                Item(Id(Ops.get(i, 0, "")), Ops.get(i, 1, Ops.get(i, 0, "")))
              end
            )
          )
        elsif widget == :multi_line_edit
          Ops.set(w, "widget", MultiLineEdit(id_term, opt_term, label))
        elsif widget == :richtext
          Ops.set(w, "widget", RichText(id_term, opt_term, ""))
        end
      end
      Ops.set(w, "custom_widget", nil) # not needed any more
      deep_copy(w)
    end

    # Validate single widget
    # @param [Hash{String => Object}] widget widget description map
    # @param [Hash] event map event that caused validation
    # @param [String] key widget key for validation by function
    # @return true if validation succeeded
    def validateWidget(widget, event, key)
      widget = deep_copy(widget)
      event = deep_copy(event)
      @processed_widget = deep_copy(widget)
      failed = false
      val_type = Ops.get_symbol(widget, "validate_type")
      if val_type == :function || val_type == :function_no_popup
        toEval = Convert.convert(
          Ops.get(widget, "validate_function"),
          from: "any",
          to:   "boolean (string, map)"
        )
        failed = !toEval.call(key, event) if !toEval.nil?
      elsif val_type == :regexp
        regexp = Ops.get_string(widget, "validate_condition", "")
        if !Builtins.regexpmatch(
          Convert.to_string(UI.QueryWidget(Id(:_tp_value), :Value)),
          regexp
        )
          failed = true
        end
      elsif val_type == :list
        possible = Ops.get_list(widget, "validate_condition", [])
        if !Builtins.contains(possible, UI.QueryWidget(Id(:_tp_value), :Value))
          failed = true
        end
      end

      if failed && val_type != :function
        error = Ops.get_string(widget, "validate_help", "")
        if error == ""
          wname = Ops.get_string(
            widget,
            "label",
            Ops.get_string(widget, "_cwm_key", "")
          )
          wname = Builtins.deletechars(wname, "&")
          # message popup, %1 is a label of some widget
          error = Builtins.sformat(_("The value of %1 is invalid."), wname)
        end
        UI.SetFocus(Id(Ops.get_string(widget, "_cwm_key", "")))
        Report.Error(error)
      end
      !failed
    end

    # Validate dialog contents for allow it to be saved
    # @param [Array<Hash{String => Object>}] widgets list of widgets to validate
    # @param [Hash] event map event that caused validation
    # @return [Boolean] true if everything is OK, false  if something is wrong
    def validateWidgets(widgets, event)
      widgets = deep_copy(widgets)
      event = deep_copy(event)
      result = true
      Builtins.foreach(widgets) do |w|
        widget_key = Ops.get_string(w, "_cwm_key", "")
        result &&= validateWidget(w, event, widget_key)
      end
      if !result && !@validation_failed_handler.nil?
        @validation_failed_handler.call
      end
      result
    end

    # Read widgets with listed names
    # @param [Array<String>] names a list of strings/symbols names of widgets
    # @param [Hash <String, Hash{String => Object>}] source a map containing the widgets
    # @return [Array] of maps representing widgets
    def CreateWidgets(names, source)
      names = deep_copy(names)
      source = deep_copy(source)
      ValidateMaps(source) # FIXME: find better place
      ret = Builtins.maplist(names) do |w|
        m = Ops.get(source, w, {})
        # leave add here in order to make a copy of the structure
        # eval isn't usable because the map may contain terms, that can't
        # be evaluated here
        m = Builtins.add(m, "_cwm_key", w)
        deep_copy(m)
      end
      ret = Builtins.maplist(ret) { |w| prepareWidget(w) }
      deep_copy(ret)
    end

    # Merge helps from the widgets
    # @param [Array<Hash{String => Object>}] widgets a list of widget description maps
    # @return [String] merged helps of the widgets
    def MergeHelps(widgets)
      widgets = deep_copy(widgets)
      helps = Builtins.maplist(widgets) { |w| Ops.get_string(w, "help") }
      helps = Builtins.filter(helps) { |h| !h.nil? }
      Builtins.mergestring(helps, "\n")
    end

    # Prepare the dialog, replace strings in the term with appropriate
    # widgets
    # @param [Yast::Term] dialog term dialog containing strings
    # @param [Array<Hash{String => Object>}] widgets list of widget description maps
    # @return updated term ready to be used as a dialog
    def PrepareDialog(dialog, widgets)
      dialog = deep_copy(dialog)
      widgets = deep_copy(widgets)
      args = Builtins.size(dialog)
      return deep_copy(dialog) if args == 0
      m = Builtins.listmap(widgets) do |w|
        widget_key = Ops.get_string(w, "_cwm_key", "")
        { widget_key => w }
      end
      ProcessTerm(dialog, m)
    end

    # Replace help for a particular widget
    # @param [String] widget string widget ID of widget to replace help
    # @param [String] help string new help to the widget
    def ReplaceWidgetHelp(widget, help)
      @current_dialog_widgets = Builtins.maplist(@current_dialog_widgets) do |w|
        Ops.set(w, "help", help) if Ops.get_string(w, "_cwm_key", "") == widget
        deep_copy(w)
      end
      help = MergeHelps(@current_dialog_widgets)
      Wizard.RestoreHelp(help)

      nil
    end

    # A hook to handle Alt-Ctrl-Shift-D
    def handleDebug
      Builtins.y2debug("Handling a debugging event")

      nil
    end

    # Generic function to create dialog and handle it's events
    # @param [Array<Hash{String => Object>}] widgets list of widget maps
    # @param [Hash] functions map initialize/save/handle fallbacks if not specified
    #   with the widgets.
    # @param [Array<Object>] skip_store_for list of events for which the value of the widget will not be stored
    #   Useful mainly for non-standard redraw of widgets, like :reset or :redraw
    # @return [Symbol] wizard sequencer symbol
    def Run(widgets, functions, skip_store_for: [])
      widgets = deep_copy(widgets)
      functions = deep_copy(functions)
      widgets = mergeFunctions(widgets, functions)
      PushSettings()
      @current_dialog_widgets = deep_copy(widgets)
      initWidgets(widgets)

      # allow a handler to enable/disable widgets before the first real
      # UserInput takes place
      UI.FakeUserInput("ID" => "_cwm_wakeup")

      ret = nil
      save_exits = [:next, :ok]
      save = false
      event_descr = {}
      timeout = GetLowestTimeout(widgets)
      while ret != :back && ret != :abort && !save
        if Ops.greater_than(timeout, 0)
          event_descr = UI.WaitForEvent(timeout)
        else
          event_descr = UI.WaitForEvent
        end
        ret = Ops.get(event_descr, "ID")
        if Ops.get_string(event_descr, "EventType", "") == "DebugEvent"
          handleDebug
        end
        handle_ret = handleWidgets(widgets, event_descr)
        if !handle_ret.nil? ||
            Ops.is_symbol?(ret) && Builtins.contains(save_exits, ret)
          save = true
          if !handle_ret.nil?
            ret = handle_ret
            Ops.set(event_descr, "ID", ret)
          end
        end

        ret = :abort if ret == :cancel
        if ret == :abort
          if Ops.get(functions, :abort)
            toEval = Convert.convert(
              Ops.get(functions, :abort),
              from: "any",
              to:   "boolean ()"
            )
            if !toEval.nil?
              eval_ret = toEval.call
              ret = eval_ret ? :abort : nil
            end
          end
        elsif ret == :back
          if Ops.get(functions, :back)
            toEval = Convert.convert(
              Ops.get(functions, :back),
              from: "any",
              to:   "boolean ()"
            )
            if !toEval.nil?
              eval_ret = toEval.call
              ret = eval_ret ? :back : nil
            end
          end
        end

        next if ret.nil?

        ret = nil if save && (!validateWidgets(widgets, event_descr))

        if ret.nil?
          save = false
          next
        end
      end
      saveWidgets(widgets, event_descr) if save && !skip_store_for.include?(ret)
      cleanupWidgets(widgets)
      PopSettings()
      Convert.to_symbol(ret)
    end

    # Disable given bottom buttons of the wizard sequencer
    # @patam buttons list of buttons to be disabled
    def DisableButtons(buttons)
      buttons = deep_copy(buttons)
      Builtins.foreach(buttons) do |button|
        Wizard.DisableBackButton if button == "back_button"
        Wizard.DisableAbortButton if button == "abort_button"
        Wizard.DisableNextButton if button == "next_button"
      end

      nil
    end

    # Adjust the labels of the bottom buttons of the wizard sequencer
    # @param [String] next label of the "Next" button
    # @param [String] back string label of the "Back" button
    # @param [String] abort string label of the "Abort" button
    # @param [String] _help unused parameter since help button cannot be hide anyway
    def AdjustButtons(next_, back, abort, _help)
      next_ = "" if next_.nil?
      back = "" if back.nil?
      abort = "" if abort.nil?
      if next_ != ""
        Wizard.SetNextButton(:next, next_)
      else
        Wizard.HideNextButton
      end

      if abort != ""
        Wizard.SetAbortButton(:abort, abort)
      else
        Wizard.HideAbortButton
      end

      if back != ""
        Wizard.SetBackButton(:back, back)
      else
        Wizard.HideBackButton
      end

      nil
    end

    # Set handler to be called after validation of a dialog failed
    # @param [void ()] handler a function reference to be caled. If nil, nothing is called
    def SetValidationFailedHandler(handler)
      handler = deep_copy(handler)
      @validation_failed_handler = deep_copy(handler)

      nil
    end

    # Display the dialog and run its event loop using new widget API
    # @param [Yast::Term] contents is UI term including instances of CWM::AbstractWidget
    # @param [String] caption of dialog
    # @param [String] back_button label for dialog back button
    # @param [String] next_button label for dialog next button
    # @param [String] abort_button label for dialog abort button
    # @param [Array] skip_store_for list of events for which the value of the widget will not be stored.
    #   Useful mainly when some widget returns an event that should not trigger the storing,
    #   like a reset button or a redrawing
    # @return [Symbol] wizard sequencer symbol
    def show(contents, caption: nil, back_button: nil, next_button: nil, abort_button: nil, skip_store_for: [])
      widgets = widgets_in_contents(contents)
      options = {
        "contents"     => widgets_contents(contents),
        "widget_names" => widgets.map(&:widget_id),
        "widget_descr" => Hash[widgets.map { |w| [w.widget_id, w.cwm_definition] }]
      }
      options["caption"] = caption if caption
      options["back_button"] = back_button if back_button
      options["next_button"] = next_button if next_button
      options["abort_button"] = abort_button if abort_button
      options["skip_store_for"] = skip_store_for

      ShowAndRun(options)
    end

    # Display the dialog and run its event loop
    # @param [Hash<String, Object>] settings a map of all settings needed to run the dialog
    # @option settings [AbstractWidget] "widgets" list of widgets used in CWM,
    #   it is auto added to `"widget_names"` and `"widget_descr"`
    def ShowAndRun(settings)
      settings = deep_copy(settings)
      if settings["widgets"]
        widgets = settings["widgets"]
        settings["widget_names"] ||= []
        settings["widget_names"] += widgets.map(&:widget_id)
        settings["widget_descr"] ||= {}
        settings["widget_descr"] = Hash[widgets.map { |w| [w.widget_id, w.cwm_definition] }]
      end
      widget_descr = Ops.get_map(settings, "widget_descr", {})
      contents = Ops.get_term(settings, "contents", VBox())
      widget_names = Convert.convert(
        Ops.get(settings, "widget_names") { StringsOfTerm(contents) },
        from: "any",
        to:   "list <string>"
      )
      caption = Ops.get_string(settings, "caption", "")
      back_button = Ops.get_string(settings, "back_button") { Label.BackButton }
      next_button = Ops.get_string(settings, "next_button") { Label.NextButton }
      abort_button = Ops.get_string(settings, "abort_button") do
        Label.AbortButton
      end
      fallback = Ops.get_map(settings, "fallback_functions", {})

      w = CreateWidgets(widget_names, widget_descr)
      help = MergeHelps(w)
      contents = PrepareDialog(contents, w)
      Wizard.SetContentsButtons(
        caption,
        contents,
        help,
        back_button,
        next_button
      )
      AdjustButtons(next_button, back_button, abort_button, nil)
      DisableButtons(Ops.get_list(settings, "disable_buttons", []))

      skip_store_for = settings["skip_store_for"] || []
      Run(w, fallback, skip_store_for: skip_store_for)
    end

    # Display the dialog and run its event loop
    # @param [Array<String>] widget_names list of names of widgets that will be used in the
    #   dialog
    # @param [Hash <String, Hash{String => Object>}] widget_descr map description map of all widgets
    # @param [Yast::Term] contents term contents of the dialog, identifiers instead of
    #   widgets
    # @param [String] caption string dialog caption
    # @param [String] back_button string label of the back button
    # @param [String] next_button string label of the next button
    # @param [Hash] fallback map initialize/save/handle fallbacks if not specified
    #   with the widgets.
    # @return [Symbol] wizard sequencer symbol
    def ShowAndRunOrig(widget_names, widget_descr, contents, caption, back_button, next_button, fallback)
      widget_names = deep_copy(widget_names)
      widget_descr = deep_copy(widget_descr)
      contents = deep_copy(contents)
      fallback = deep_copy(fallback)
      ShowAndRun(

        "widget_names"       => widget_names,
        "widget_descr"       => widget_descr,
        "contents"           => contents,
        "caption"            => caption,
        "back_button"        => back_button,
        "next_button"        => next_button,
        "fallback_functions" => fallback

      )
    end

    # useful handlers

    # Do-nothing replacement for a widget initialization function.
    # Used for push buttons if all the other widgets have a fallback.
    # @param [String] key id of the widget
    def InitNull(_key)
      nil
    end

    # Do-nothing replacement for a widget storing function.
    # Used for push buttons if all the other widgets have a fallback.
    # @param [String] key	id of the widget
    # @param [Hash] event	the event being handled
    def StoreNull(_key, _event)
      nil
    end

    # Saves changes of all the widgets in the current dialog
    #
    # @param [Hash] event map event that triggered the saving
    def save_current_widgets(event)
      saveWidgets(@current_dialog_widgets, event)
    end

    # Validates all the widgets in the current dialog
    #
    # @param [Hash] event map event that caused validation
    # @return [Boolean] true if everything is OK, false  if something is wrong
    def validate_current_widgets(event)
      validateWidgets(@current_dialog_widgets, event)
    end

    publish function: :StringsOfTerm, type: "list <string> (term)"
    publish function: :ValidateBasicType, type: "boolean (any, string)"
    publish function: :ValidateValueType, type: "boolean (string, any, string)"
    publish function: :mergeFunctions, type: "list <map <string, any>> (list <map <string, any>>, map)"
    publish function: :initWidgets, type: "void (list <map <string, any>>)"
    publish function: :handleWidgets, type: "symbol (list <map <string, any>>, map)"
    publish function: :saveWidgets, type: "void (list <map <string, any>>, map)"
    publish function: :cleanupWidgets, type: "void (list <map <string, any>>)"
    publish function: :GetProcessedWidget, type: "map <string, any> ()"
    publish function: :OkCancelBox, type: "term ()"
    publish function: :ValidateMaps, type: "boolean (map <string, map <string, any>>)"
    publish function: :prepareWidget, type: "map <string, any> (map <string, any>)"
    publish function: :validateWidget, type: "boolean (map <string, any>, map, string)"
    publish function: :validateWidgets, type: "boolean (list <map <string, any>>, map)"
    publish function: :CreateWidgets, type: "list <map <string, any>> (list <string>, map <string, map <string, any>>)"
    publish function: :MergeHelps, type: "string (list <map <string, any>>)"
    publish function: :PrepareDialog, type: "term (term, list <map <string, any>>)"
    publish function: :ReplaceWidgetHelp, type: "void (string, string)"
    publish function: :Run, type: "symbol (list <map <string, any>>, map)"
    publish function: :DisableButtons, type: "void (list <string>)"
    publish function: :AdjustButtons, type: "void (string, string, string, string)"
    publish function: :SetValidationFailedHandler, type: "void (void ())"
    publish function: :ShowAndRun, type: "symbol (map <string, any>)"
    publish function: :ShowAndRunOrig, type: "symbol (list <string>, map <string, map <string, any>>, term, string, string, string, map)"
    publish function: :InitNull, type: "void (string)"
    publish function: :StoreNull, type: "void (string, map)"

    def widgets_in_contents(contents)
      contents.each_with_object([]) do |arg, res|
        case arg
        when ::CWM::CustomWidget then res.concat(arg.nested_widgets) << arg
        when ::CWM::AbstractWidget then res << arg
        when Yast::Term then res.concat(widgets_in_contents(arg))
        end
      end
    end

    def widgets_contents(contents)
      res = contents.clone

      (0..(res.size - 1)).each do |index|
        case contents[index]
        when ::CWM::AbstractWidget then res[index] = res[index].widget_id
        when Yast::Term then res[index] = widgets_contents(res[index])
        end
      end

      res
    end
  end

  CWM = CWMClass.new
  CWM.main
end
