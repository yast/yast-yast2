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
# File:	modules/LogView.ycp
# Package:	YaST2
# Summary:	Displaying a log with additional functionality
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# All of these functions watch the log file and display
# added lines as the log grows.
# <pre>
# LogView::DisplaySimple ("/var/log/messages");
# LogView::DisplayFiltered ("/var/log/messages", "\\(tftp\\|TFTP\\)");
# LogView::Display ($[
#          "file" : "/var/log/messages",
#          "grep" : "dhcpd",
#          "save" : true,
#          "actions" : [	// menu buttons
#              [ _("Restart DHCP Server"),
#                  RestartDhcpDaemon ],
#              [ _("Save Settings and Restart DHCP Server"),
#                  DhcpServer::Write ],
#          ],
#      ]);
# </pre>
require "yast"

module Yast
  class LogViewClass < Module
    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "CWM"
      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "Report"
      Yast.import "LogViewCore"

      # fallback settings variables

      # configuration variables

      # global parameters for the log displaying widget
      @param = {}

      # list of all the logs that can be displayed
      @logs = []

      # index of currently selected log
      @current_index = 0

      # list of actions that can be processed on the logs
      @mb_actions = []
    end

    # local functions

    # Get the map describing the particular log file from its index
    # @param [Fixnum] index integer index of the log file
    # @return a map describing the log file
    def Index2Descr(index)
      Ops.get(@logs, index, {})
    end

    # Starts the log reading command via process agent
    # @param [Fixnum] index integer the index of the log file
    def InitLogReading(index)
      log_descr = Index2Descr(index)
      LogViewCore.Start(Id(:_cwm_log), log_descr)

      nil
    end

    # Kill processes running on the backgrouns
    # @param [String] key log widget key
    def KillBackgroundProcess(_key)
      LogViewCore.Stop

      nil
    end

    # Get the help for the log in case of multiple logs
    # @return [String] part of the log
    def LogSelectionHelp
      # help for the log widget, part 1, alt. 1
      _(
        "<p><b><big>Displayed Log</big></b><br>\n" \
          "Use <b>Log</b> to select the log to display. It will be displayed in\n" \
          "the field below.</p>\n"
      )
    end

    # Get the help for the log in case of a single log
    # @return [String] part of the log
    def SingleLogHelp
      # help for the log widget, part 1, alt. 2
      _("<p><b><big>The Log</big></b><br>\nThis screen displays the log.</p>")
    end

    # Get the second part of the help for the log in case of advanced functions
    #  and save support
    # @param [String] label tge label of the menu button
    # @return [String] part of the log
    def AdvancedSaveHelp(label)
      # help for the log widget, part 2, alt. 1, %1 is a menu button label
      Builtins.sformat(
        _(
          "<p>\n" \
            "To process advanced actions or save the log into a file, click <b>%1</b>\n" \
            "and select the action to process.</p>"
        ),
        label
      )
    end

    # Get the second part of the help for the log in case of advanced functions
    # @param [String] label tge label of the menu button
    # @return [String] part of the log
    def AdvancedHelp(label)
      # help for the log widget, part 2, alt. 2, %1 is a menu button label
      Builtins.sformat(
        _(
          "<p>\n" \
            "To process advanced actions, click <b>%1</b>\n" \
            "and select the action to process.</p>"
        ),
        label
      )
    end

    # Get the second part of the help for the log in case of save support
    # @return [String] part of the log
    def SaveHelp
      # help for the log widget, part 2, alt. 3
      _(
        "<p>\n" \
          "To save the log into a file, click <b>Save Log</b> and select the file\n" \
          "to which to save the log.</p>\n"
      )
    end

    # Get the help of the widget
    # @param [Fixnum] logs integer count of displayed logs
    # @param [Hash] parameters map parameters of the log to display
    # @return [String] help to the widget
    def CreateHelp(logs, parameters)
      parameters = deep_copy(parameters)
      help = Ops.get_string(parameters, "help", "")
      return help if help != "" && !help.nil?

      adv_button = Ops.get_string(parameters, "mb_label", "")
      if adv_button == "" || adv_button.nil?
        # menu button
        adv_button = _("Ad&vanced")
      end

      if Builtins.regexpmatch(adv_button, "^.*&.*$")
        adv_button = Builtins.regexpsub(adv_button, "^(.*)&(.*)$", "\\1\\2")
      end

      save = Ops.get_boolean(parameters, "save", false)
      save = false if save.nil?

      actions_lst = Ops.get_list(parameters, "actions", [])
      actions_lst = [] if actions_lst.nil?
      actions = Builtins.size(actions_lst)

      actions = Ops.add(actions, 1) if save

      if Ops.greater_than(logs, 1)
        help = LogSelectionHelp()
      elsif Ops.greater_or_equal(actions, 1) || save
        help = SingleLogHelp()
      else
        return ""
      end

      if Ops.greater_or_equal(actions, 2)
        help = if save
          Ops.add(help, AdvancedSaveHelp(adv_button))
               else
          Ops.add(help, AdvancedHelp(adv_button))
        end
      elsif save
        help = Ops.add(help, SaveHelp())
      end

      help
    end

    # Get the combo box of the available log files
    # @param [Array<Hash{String => Object>}] log_maps a list of maps describing all the logs
    # @return [Yast::Term] the combo box widget
    def GetLogSelectionCombo(log_maps)
      log_maps = deep_copy(log_maps)
      selection_combo = Empty()
      if Ops.greater_than(Builtins.size(log_maps), 0)
        index = -1
        items = Builtins.maplist(log_maps) do |m|
          index = Ops.add(index, 1)
          Item(
            Id(index),
            Ops.get_locale(
              # combo box entry (only used as fallback in case
              # of error in the YaST code)
              m,
              "log_label",
              Ops.get_locale(m, "command", Ops.get_locale(m, "file", _("Log")))
            )
          )
        end
        selection_combo = ComboBox(
          Id(:cwm_log_files),
          Opt(:notify, :hstretch),
          _("&Log"),
          items
        )
      end
      deep_copy(selection_combo)
    end

    # Get the widget with the menu button with actions to be processed on the log
    # @param [Array<Array>] actions a list of all actions
    # @param [Boolean] save boolean true if the log should be offered to be saved
    # @param [String] mb_label label of the menu button, may be empty for default
    # @return [Yast::Term] widget with the menu button
    def GetMenuButtonWidget(actions, save, mb_label)
      actions = deep_copy(actions)
      menubutton = []
      if save
        # menubutton entry
        menubutton = Builtins.add(menubutton, [:_cwm_log_save, _("&Save Log")])
      end

      if Ops.greater_than(Builtins.size(actions), 0)
        index = 0
        Builtins.foreach(actions) do |a|
          menubutton = Builtins.add(
            menubutton,
            [index, Ops.get_string(a, 0, "")]
          )
          index = Ops.add(index, 1)
        end
      end

      if Ops.greater_than(Builtins.size(menubutton), 1)
        menubutton = Builtins.filter(menubutton) do |m|
          m.is_a?(Array) && m.first
        end
        menubutton = Builtins.maplist(menubutton) do |m|
          ml = Convert.to_list(m)
          Item(Id(Ops.get(ml, 0)), Ops.get_string(ml, 1, ""))
        end
        mb_label = _("Ad&vanced") if mb_label == "" || mb_label.nil?
        return MenuButton(Id(:_cwm_log_menu), mb_label, menubutton)
      elsif Builtins.size(menubutton) == 1
        return PushButton(
          Id(Ops.get(menubutton, [0, 0], "")),
          Ops.get_string(menubutton, [0, 1], "")
        )
      end
      Empty()
    end

    # Get the buttons below the box with the log
    # @param [Boolean] popup boolean true if running in popup (and Close is needed)
    # @param [Hash{String => Object}] glob_param a map of global parameters of the log widget
    # @param [Array<Hash{String => Object>}] log_maps a list of maps describing all the logs
    # @return [Yast::Term] the widget with buttons
    def GetButtonsBelowLog(popup, glob_param, _log_maps)
      glob_param = deep_copy(glob_param)
      left = Empty()
      center = Empty()

      if popup
        center = PushButton(Id(:close), Opt(:key_F9), Label.CloseButton)

        if Builtins.haskey(glob_param, "help") &&
            Ops.get_string(glob_param, "help", "") != ""
          left = PushButton(Id(:help), Label.HelpButton)
        end
      end

      save = Ops.get_boolean(glob_param, "save", false)
      mb_label = Ops.get_locale(glob_param, "mb_label", _("Ad&vanced"))
      actions = Ops.get_list(glob_param, "actions", [])
      right = GetMenuButtonWidget(actions, save, mb_label)

      HBox(
        HWeight(1, left),
        HStretch(),
        HWeight(1, center),
        HStretch(),
        HWeight(1, right)
      )
    end

    # Get the default entry for the combo box with logs
    # @param [Array<Hash{String => Object>}] log_maps a list of maps describing all the logs
    # @return [Fixnum] the index of the default entry in the combo box
    def GetDefaultItemForLogsCombo(log_maps)
      log_maps = deep_copy(log_maps)
      default_log = 0
      if Ops.greater_than(Builtins.size(log_maps), 0)
        index = -1
        Builtins.foreach(log_maps) do |m|
          index = Ops.add(index, 1)
          if Builtins.haskey(m, "default") && default_log == 0
            default_log = index
          end
        end
      end
      default_log
    end

    # Switch the displayed log
    # @param [Fixnum] index integer index of the log to display
    def LogSwitch(index)
      @current_index = index

      log_descr = Index2Descr(index)
      # logview caption
      caption = Ops.get_locale(
        log_descr,
        "log_label",
        Ops.get_locale(@param, "log_label", _("&Log"))
      )

      UI.ReplaceWidget(:_cwm_log_rp, LogView(Id(:_cwm_log), caption, 15, 0))

      InitLogReading(index)

      nil
    end

    # Initialize the displayed log
    # @param [String] key log widget key
    # @param [String] key table widget key
    def LogInit(_key)
      @param = CWM.GetProcessedWidget
      @current_index = Ops.get_integer(@param, "_cwm_default_index", 0)
      @mb_actions = Ops.get_list(@param, "_cwm_button_actions", [])
      @logs = Ops.get_list(@param, "_cwm_log_files", [])
      if UI.WidgetExists(Id(:cwm_log_files))
        UI.ChangeWidget(Id(:cwm_log_files), :value, @current_index)
      end
      LogSwitch(@current_index)

      nil
    end

    # Handle the event on the log view widget
    # @param [String] key log widget key
    # @param [Hash] event map event to handle
    # @return [Symbol] always nil
    def LogHandle(_key, event)
      event = deep_copy(event)
      @param = CWM.GetProcessedWidget
      LogViewCore.Update(Id(:_cwm_log))
      ret = Ops.get(event, "ID")
      # save the displayed log to file
      if ret == :_cwm_log_save
        filename = UI.AskForSaveFileName(
          # popup caption, save into home directory by default (bnc#653601)
          "~",
          "*.log",
          _("Save Log as...")
        )
        if !filename.nil?
          SCR.Write(
            path(".target.string"),
            filename,
            Ops.add(Builtins.mergestring(LogViewCore.GetLines, "\n"), "\n")
          )
        end
      # other operation specified by user
      elsif !ret.nil? && Ops.is_integer?(ret)
        iret = Convert.to_integer(ret)
        func = Convert.convert(
          Ops.get(@mb_actions, [iret, 1]),
          from: "any",
          to:   "void ()"
        )
        func.call if !func.nil?
        if Ops.get(@mb_actions, [iret, 2]) == true
          KillBackgroundProcess(nil)
          UI.ChangeWidget(Id(:_cwm_log), :Value, "")
          InitLogReading(@current_index)
        end
      # switch displayed log file
      elsif ret == :cwm_log_files
        index = Convert.to_integer(UI.QueryWidget(Id(:cwm_log_files), :Value))
        LogSwitch(index)
      end
      nil
    end

    # Get the map with the log view widget
    # @param [Hash{String => Object}] parameters map parameters of the widget to be created, will be
    #  unioned with the generated map
    # <pre>
    #  - "save" -- boolean, if true, then log saving is possible
    #  - "actions" -- list, allows to specify additional actions.
    #                 Each member is a 2- or 3-entry list, first entry is a
    #                 label for the menubutton, the second one is a function
    #                 that will be called when the entry is selected,
    #                 the signature of the function must be void(),
    #			optional 3rd argument, if set to true, forces
    #			restarting of the log displaying command after the
    #			action is performed
    #  - "mb_label" -- string, label of the menubutton, if not specified,
    #                  then "Advanced" is used
    #  - "max_lines" -- integer, maximum of lines to be displayed. If 0,
    #                   then display whole file. Default is 100.
    #  - "help" -- string for a rich text, help to be offered via a popup
    #              when user clicks the "Help" button. If not present,
    #              default help is shown or Help button is hidden.
    # - "widget_height" -- height of the LogView widget, to be adjusted
    #                      so that the widget fits into the dialog well.
    #                      Test it to find the best value, 15 seems to be
    #                      good value (is default if not specified)
    # </pre>
    # @param [Array<Hash{String => Object>}] log_files a list of logs that will be displayed
    # <pre>
    #  - "file" -- string, filename with the log
    #  - "grep" -- string, basic regular expression to be grepped
    #              in the log (for getting relevant  parts of
    #              /var/log/messages. If empty or not present, whole file
    #              is used
    #  - "command" -- allows to specify comand to get the log for cases
    #                 where grep isn't enough. If used, file and grep entries
    #                 are ignored
    #  - "log_label" -- header of the LogView widget, if not set, then the file
    #                   name or the command is used
    #  - "default" -- define and set to true to make this log be active after
    #                 widget is displayed. If not defiend for any log, the
    #                 first log is automatically default. If defined for multiple
    #                 logs, the first one is active
    # </pre>
    # @return [Hash] the log widget
    def CreateWidget(parameters, log_files)
      parameters = deep_copy(parameters)
      log_files = deep_copy(log_files)
      # logview caption
      caption = Ops.get_locale(@param, "log_label", _("&Log"))
      height = Ops.get_integer(@param, "widget_height", 15)

      default_index = GetDefaultItemForLogsCombo(log_files)
      top_bar = GetLogSelectionCombo(log_files)
      bottom_bar = GetButtonsBelowLog(false, parameters, log_files)

      Builtins.union(
        {
          "widget"              => :custom,
          "custom_widget"       => VBox(
            top_bar,
            ReplacePoint(
              Id(:_cwm_log_rp),
              LogView(Id(:_cwm_log), caption, height, 0)
            ),
            bottom_bar
          ),
          "init"                => fun_ref(method(:LogInit), "void (string)"),
          "handle"              => fun_ref(
            method(:LogHandle),
            "symbol (string, map)"
          ),
          "cleanup"             => fun_ref(
            method(:KillBackgroundProcess),
            "void (string)"
          ),
          "ui_timeout"          => 1000,
          "_cwm_default_index"  => default_index,
          "_cwm_log_files"      => log_files,
          "_cwm_button_actions" => [],
          "help"                => CreateHelp(
            Builtins.size(log_files),
            parameters
          )
        },
        parameters
      )
    end

    # old functions for displaying log as a popup

    # Main function for displaying logs
    # @param [Hash{String => Object}] parameters map description of parameters, with following keys
    # <pre>
    #  - "file" -- string, filename with the log
    #  - "grep" -- string, basic regular expression to be grepped
    #              in the log (for getting relevant  parts of
    #              /var/log/messages. If empty or not present, whole file
    #              is used
    #  - "command" -- allows to specify command to get the log for cases
    #                 where grep isn't enough. If used, file and grep entries
    #                 are ignored
    #  - "save" -- boolean, if true, then log saving is possible
    #  - "actions" -- list, allows to specify additional actions.
    #                 Each member is a 2- or 3-entry list, first entry is a
    #                 label for the menubutton, the second one is a function
    #                 that will be called when the entry is selected,
    #                 the signature of the function must be void(),
    #			optional 3rd argument, if set to true, forces
    #			restarting of the log displaying command after the
    #			action is performed
    #  - "help" -- string for a rich text, help to be offered via a popup
    #              when user clicks the "Help" button. If not present,
    #              Help button isn't shown
    #  - "mb_label" -- string, label of the menubutton, if not specified,
    #                  then "Advanced" is used
    #  - "max_lines" -- integer, maximum of lines to be displayed. If 0,
    #                   then display whole file. Default is 100.
    #  - "log_label" -- header of the LogView widget, if not set, then "Log"
    #                   is used
    # </pre>
    def Display(parameters)
      parameters = deep_copy(parameters)
      @param = deep_copy(parameters)

      # menubutton
      log_label = Ops.get_locale(@param, "log_label", _("&Log"))

      @logs = [@param]

      button_line = GetButtonsBelowLog(true, @param, [@param])

      UI.OpenDialog(
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(1),
            HSpacing(70),
            # log view header
            LogView(Id(:_cwm_log), log_label, 19, 0),
            VSpacing(1),
            button_line,
            VSpacing(1)
          ),
          HSpacing(1)
        )
      )

      if Ops.get_string(@param, "help", "") != ""
        UI.ReplaceWidget(Id(:rep_left), PushButton(Id(:help), Label.HelpButton))
      end
      @mb_actions = Ops.get_list(@param, "actions", [])

      InitLogReading(0)

      ret = nil
      while ret != :close && ret != :cancel
        event = UI.WaitForEvent(1000)
        ret = Ops.get(event, "ID")
        if ret == :help
          UI.OpenDialog(
            VBox(
              RichText(Id(:help_text), Ops.get_string(@param, "help", "")),
              HBox(
                HStretch(),
                PushButton(Id(:close), Label.CloseButton),
                HStretch()
              )
            )
          )
          ret = UI.UserInput while ret != :close && ret != :cancel
          ret = nil
          UI.CloseDialog
        else
          LogHandle("", event)
        end
      end
      LogViewCore.Stop
      UI.CloseDialog
      nil
    end

    # Display specified file, list 100 lines
    # @param [String] file string filename of file with the log
    def DisplaySimple(file)
      Display("file" => file)

      nil
    end

    # Display log with filtering with 100 lines
    # @param [String] file string filename of file with the log
    # @param [String] grep string basic regular expression to be grepped in file
    def DisplayFiltered(file, grep)
      Display("file" => file, "grep" => grep)

      nil
    end

    publish function: :LogSelectionHelp, type: "string ()"
    publish function: :SingleLogHelp, type: "string ()"
    publish function: :AdvancedSaveHelp, type: "string (string)"
    publish function: :AdvancedHelp, type: "string (string)"
    publish function: :SaveHelp, type: "string ()"
    publish function: :LogInit, type: "void (string)"
    publish function: :LogHandle, type: "symbol (string, map)"
    publish function: :CreateWidget, type: "map (map <string, any>, list <map <string, any>>)"
    publish function: :Display, type: "void (map <string, any>)"
    publish function: :DisplaySimple, type: "void (string)"
    publish function: :DisplayFiltered, type: "void (string, string)"
  end

  LogView = LogViewClass.new
  LogView.main
end
