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
# File:	modules/Report.ycp
# Package:	yast2
# Summary:	Messages handling
# Authors:	Ladislav Slezak <lslezak@suse.cz>
# Flags:	Stable
#
# $Id$
#
#
require "yast"

module Yast
  # Report module is universal reporting module. It properly display messages
  # in CLI, TUI, GUI or even in automatic installation. It also collects
  # warnings and errors. Collected messages can be displayed later.
  # @TODO not all methods respect all environment, feel free to open issue with
  #   method that doesn't respect it.
  class ReportClass < Module
    def main
      textdomain "base"

      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Summary"

      # stored messages
      @errors = []
      @warnings = []
      @messages = []
      @yesno_messages = []

      # display flags
      @display_errors = true
      @display_warnings = true
      @display_messages = true
      @display_yesno_messages = true

      # timeouts
      @timeout_errors = 0
      @timeout_warnings = 0
      @timeout_messages = 0
      @timeout_yesno_messages = 0

      # logging flags
      @log_errors = true
      @log_warnings = true
      @log_messages = true
      @log_yesno_messages = true

      @message_settings = {}
      @error_settings = {}
      @warning_settings = {}
      @yesno_message_settings = {}

      # default value of settings modified
      @modified = false
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # Summary of current settings
    # @return Html formatted configuration summary
    def Summary
      summary = ""
      # translators: summary header for messages generated through autoinstallation
      summary = Summary.AddHeader(summary, _("Messages"))
      summary = Summary.OpenList(summary)

      # Report configuration - will be normal messages displayed?
      # '%1' will be replaced by translated string "Yes" or "No"
      summary = Summary.AddListItem(
        summary,
        Builtins.sformat(
          _("Display Messages: %1"),
          # translators: summary if the messages should be displayed
          @display_messages ? _("Yes") : _("No")
        )
      )
      # Report configuration - will have normal messages timeout?
      # '%1' will be replaced by number of seconds
      summary = Summary.AddListItem(
        summary,
        Builtins.sformat(_("Time-out Messages: %1"), @timeout_messages)
      )
      # Report configuration - will be normal messages logged to file?
      # '%1' will be replaced by translated string "Yes" or "No"
      summary = Summary.AddListItem(
        summary,
        Builtins.sformat(
          _("Log Messages: %1"),
          # translators: summary if the messages should be written to log file
          @log_messages ? _("Yes") : _("No")
        )
      )
      summary = Summary.CloseList(summary)
      # translators: summary header for warnings generated through autoinstallation
      summary = Summary.AddHeader(summary, _("Warnings"))
      summary = Summary.OpenList(summary)
      # Report configuration - will be warning messages displayed?
      # '%1' will be replaced by translated string "Yes" or "No"
      summary = Summary.AddListItem(
        summary,
        Builtins.sformat(
          _("Display Warnings: %1"),
          # translators: summary if the warnings should be displayed
          @display_warnings ? _("Yes") : _("No")
        )
      )
      # Report configuration - will have warning messages timeout?
      # '%1' will be replaced by number of seconds
      summary = Summary.AddListItem(
        summary,
        Builtins.sformat(_("Time-out Warnings: %1"), @timeout_warnings)
      )
      # Report configuration - will be warning messages logged to file?
      # '%1' will be replaced by translated string "Yes" or "No"
      summary = Summary.AddListItem(
        summary,
        Builtins.sformat(
          _("Log Warnings: %1"),
          # translators: summary if the warnings should be written to log file
          @log_warnings ? _("Yes") : _("No")
        )
      )
      summary = Summary.CloseList(summary)
      # translators: summary header for errors generated through autoinstallation
      summary = Summary.AddHeader(summary, _("Errors"))
      summary = Summary.OpenList(summary)
      # Report configuration - will be error messages displayed?
      # '%1' will be replaced by translated string "Yes" or "No"
      summary = Summary.AddListItem(
        summary,
        Builtins.sformat(
          _("Display Errors: %1"),
          # translators: summary if the errors should be displayed
          @display_errors ? _("Yes") : _("No")
        )
      )
      # Report configuration - will have error messages timeout?
      # '%1' will be replaced by number of seconds
      summary = Summary.AddListItem(
        summary,
        Builtins.sformat(_("Time-out Errors: %1"), @timeout_errors)
      )
      # Report configuration - will be error messages logged to file?
      # '%1' will be replaced by translated string "Yes" or "No"
      summary = Summary.AddListItem(
        summary,
        Builtins.sformat(
          _("Log Errors: %1"),
          # translators: summary if the errors should be written to log file
          @log_errors ? _("Yes") : _("No")
        )
      )
      summary = Summary.CloseList(summary)
      # summary = Summary::AddHeader(summary, _("Yes or No Messages (Critical Messages)"));
      # summary = Summary::OpenList(summary);
      # // Report configuration - will be error messages displayed?
      # // '%1' will be replaced by translated string "Yes" or "No"
      # summary = Summary::AddListItem(summary, sformat(_("Display Yes or No Messages: %1"), (display_yesno_messages) ?
      # 						    _("Yes") : _("No")));
      # // Report configuration - will have error messages timeout?
      # // '%1' will be replaced by number of seconds
      # summary = Summary::AddListItem(summary, sformat(_("Time-out Yes or No Messages: %1"), timeout_yesno_messages));
      # // Report configuration - will be error messages logged to file?
      # // '%1' will be replaced by translated string "Yes" or "No"
      # summary = Summary::AddListItem(summary, sformat(_("Log Yes or No Messages: %1"), (log_yesno_messages) ?
      # 						    _("Yes") : _("No")));
      # summary = Summary::CloseList(summary);
      summary
    end

    # Get all the Report configuration from a map.
    #
    # the map may be empty.
    #
    # @param [Hash] settings Map with settings (keys: "messages", "errors", "warnings"; values: map
    # @return	success
    def Import(settings)
      settings = deep_copy(settings)
      @message_settings = Ops.get_map(settings, "messages", {})
      @error_settings = Ops.get_map(settings, "errors", {})
      @warning_settings = Ops.get_map(settings, "warnings", {})
      @yesno_message_settings = Ops.get_map(settings, "yesno_messages", {})

      # display flags
      @display_errors = Ops.get_boolean(@error_settings, "show", true)
      @display_warnings = Ops.get_boolean(@warning_settings, "show", true)
      @display_messages = Ops.get_boolean(@message_settings, "show", true)
      @display_yesno_messages = Ops.get_boolean(
        @yesno_message_settings,
        "show",
        true
      )

      # timeouts
      @timeout_errors = Ops.get_integer(@error_settings, "timeout", 0)
      @timeout_warnings = Ops.get_integer(@warning_settings, "timeout", 0)
      @timeout_messages = Ops.get_integer(@message_settings, "timeout", 0)
      @timeout_yesno_messages = Ops.get_integer(
        @yesno_message_settings,
        "timeout",
        0
      )

      # logging flags
      @log_errors = Ops.get_boolean(@error_settings, "log", true)
      @log_warnings = Ops.get_boolean(@warning_settings, "log", true)
      @log_messages = Ops.get_boolean(@message_settings, "log", true)
      @log_yesno_messages = Ops.get_boolean(
        @yesno_message_settings,
        "log",
        true
      )

      true
    end

    # Dump the Report settings to a map, for autoinstallation use.
    # @return [Hash] Map with settings
    def Export
      {
        "messages"       => {
          "log"     => @log_messages,
          "timeout" => @timeout_messages,
          "show"    => @display_messages
        },
        "errors"         => {
          "log"     => @log_errors,
          "timeout" => @timeout_errors,
          "show"    => @display_errors
        },
        "warnings"       => {
          "log"     => @log_warnings,
          "timeout" => @timeout_warnings,
          "show"    => @display_warnings
        },
        "yesno_messages" => {
          "log"     => @log_yesno_messages,
          "timeout" => @timeout_yesno_messages,
          "show"    => @display_yesno_messages
        }
      }
    end

    # Clear stored yes/no messages
    # @return [void]
    def ClearYesNoMessages
      @yesno_messages = []

      nil
    end

    # Clear stored messages
    # @return [void]
    def ClearMessages
      @messages = []

      nil
    end

    # Clear stored errors
    # @return [void]
    def ClearErrors
      @errors = []

      nil
    end

    # Clear stored warnings
    # @return [void]
    def ClearWarnings
      @warnings = []

      nil
    end

    # Clear all stored messages (errors, messages and warnings)
    # @return [void]
    def ClearAll
      ClearErrors()
      ClearWarnings()
      ClearMessages()
      ClearYesNoMessages()

      nil
    end

    # Return number of stored yes/no messages
    # @return [Fixnum] number of messages
    def NumYesNoMessages
      Builtins.size(@yesno_messages)
    end

    # Return number of stored messages
    # @return [Fixnum] number of messages
    def NumMessages
      Builtins.size(@messages)
    end

    # Return number of stored warnings
    # @return [Fixnum] number of warnings
    def NumWarnings
      Builtins.size(@warnings)
    end

    # Return number of stored errors
    # @return [Fixnum] number of errors
    def NumErrors
      Builtins.size(@errors)
    end

    # Question with headline and Yes/No Buttons
    # @param [String] headline Popup Headline
    # @param [String] message Popup Message
    # @param [String] yes_button_message Yes Button Message
    # @param [String] no_button_message No Button Message
    # @param [Symbol] focus Which Button has the focus
    # @return [Boolean] True if Yes is pressed, otherwise false
    def AnyQuestion(headline, message, yes_button_message, no_button_message, focus)
      Builtins.y2milestone(1, "%1", message) if @log_yesno_messages

      ret = false
      if @display_yesno_messages
        ret = if Ops.greater_than(@timeout_yesno_messages, 0)
                Popup.TimedAnyQuestion(
                  headline,
                  message,
                  yes_button_message,
                  no_button_message,
                  focus,
                  @timeout_yesno_messages
                )
        else
                Popup.AnyQuestion(
                  headline,
                  message,
                  yes_button_message,
                  no_button_message,
                  focus
                )
        end
      end

      @yesno_messages = Builtins.add(@yesno_messages, message)
      ret
    end

    # Question with headline and Yes/No Buttons
    # @param [String] headline Popup Headline
    # @param [String] message Popup Message
    # @param [String] yes_button_message Yes Button Message
    # @param [String] no_button_message No Button Message
    # @param [Symbol] focus Which Button has the focus
    # @return [Boolean] True if Yes is pressed, otherwise false
    def ErrorAnyQuestion(headline, message, yes_button_message, no_button_message, focus)
      Builtins.y2milestone(1, "%1", message) if @log_yesno_messages

      ret = false
      if @display_yesno_messages
        ret = if Ops.greater_than(@timeout_yesno_messages, 0)
                Popup.TimedErrorAnyQuestion(
                  headline,
                  message,
                  yes_button_message,
                  no_button_message,
                  focus,
                  @timeout_yesno_messages
                )
        else
                Popup.ErrorAnyQuestion(
                  headline,
                  message,
                  yes_button_message,
                  no_button_message,
                  focus
                )
        end
      end

      @yesno_messages = Builtins.add(@yesno_messages, message)
      ret
    end

    # Store new message text
    # @param [String] message_string message text, it can contain new line characters ("\n")
    # @return [void]
    def Message(message_string)
      Builtins.y2milestone(1, "%1", message_string) if @log_messages

      if @display_messages
        if Ops.greater_than(@timeout_messages, 0)
          Popup.TimedMessage(message_string, @timeout_messages)
        else
          Popup.Message(message_string)
        end
      end

      @messages = Builtins.add(@messages, message_string)

      nil
    end

    # Store new message text, the text is displayed in a richtext widget - long lines are automatically wrapped
    # @param [String] message_string message text (it can contain rich text tags)
    # @return [void]
    def LongMessage(message_string)
      Builtins.y2milestone(1, "%1", message_string) if @log_messages

      if @display_messages
        if Ops.greater_than(@timeout_messages, 0)
          Popup.TimedLongMessage(message_string, @timeout_messages)
        else
          Popup.LongMessage(message_string)
        end
      end

      @messages = Builtins.add(@messages, message_string)

      nil
    end

    # Store new message text
    # @param [String] headline_string Headline String
    # @param [String] message_string message text, it can contain new line characters ("\n")
    # @return [void]
    def ShowText(headline_string, message_string)
      Builtins.y2milestone(1, "%1", message_string) if @log_errors

      if @display_errors
        if Ops.greater_than(@timeout_errors, 0)
          Popup.ShowTextTimed(headline_string, message_string, @timeout_errors)
        else
          Popup.ShowText(headline_string, message_string)
        end
      end

      @messages = Builtins.add(@messages, message_string)

      nil
    end

    # Store new warning text
    # @param [String] warning_string warning text, it can contain new line characters ("\n")
    # @return [void]
    def Warning(warning_string)
      Builtins.y2warning(1, "%1", warning_string) if @log_warnings

      if @display_warnings
        if Ops.greater_than(@timeout_warnings, 0)
          Popup.TimedWarning(warning_string, @timeout_warnings)
        else
          Popup.Warning(warning_string)
        end
      end

      @warnings = Builtins.add(@warnings, warning_string)

      nil
    end

    # Store new warning text, the text is displayed in a richtext widget - long lines are automatically wrapped
    # @param [String] warning_string warning text (it can contain rich text tags)
    # @return [void]
    def LongWarning(warning_string)
      Builtins.y2warning(1, "%1", warning_string) if @log_warnings

      if @display_warnings
        if Ops.greater_than(@timeout_warnings, 0)
          Popup.TimedLongWarning(warning_string, @timeout_warnings)
        else
          Popup.LongWarning(warning_string)
        end
      end

      @warnings = Builtins.add(@warnings, warning_string)

      nil
    end

    # Display and record error string.
    #
    # @note Displaying can be globally disabled using Display* methods.
    # @param [String] error_string error text, it can contain new line characters ("\n")
    # @return [nil]
    def Error(error_string)
      Builtins.y2error(1, "%1", error_string) if @log_errors

      if @display_errors
        if Mode.commandline
          Yast.import "CommandLine"
          CommandLine.Print error_string
        elsif Ops.greater_than(@timeout_errors, 0)
          Popup.TimedError(error_string, @timeout_errors)
        else
          Popup.Error(error_string)
        end
      end

      @errors = Builtins.add(@errors, error_string)

      nil
    end

    # Store new error text, the text is displayed in a richtext widget - long lines are automatically wrapped
    # @param [String] error_string error text  (it can contain rich text tags)
    # @return [void]
    def LongError(error_string)
      Builtins.y2error(1, "%1", error_string) if @log_errors

      if @display_errors
        if Ops.greater_than(@timeout_errors, 0)
          Popup.TimedLongError(error_string, @timeout_errors)
        else
          Popup.LongError(error_string)
        end
      end

      @errors = Builtins.add(@errors, error_string)

      nil
    end

    # Error popup dialog can displayed immediately when new error is stored.
    #
    # This function enables or diables popuping of dialogs.
    #
    # @param [Boolean] display if true then display error popups immediately
    # @param [Fixnum] timeout dialog is automatically closed after timeout seconds. Value 0 means no time out, dialog will be closed only by user.
    # @return [void]
    def DisplayErrors(display, timeout)
      @display_errors = display
      @timeout_errors = timeout
      nil
    end

    # Warning popup dialog can displayed immediately when new warningr is stored.
    #
    # This function enables or diables popuping of dialogs.
    #
    # @param [Boolean] display if true then display warning popups immediately
    # @param [Fixnum] timeout dialog is automatically closed after timeout seconds. Value 0 means no time out, dialog will be closed only by user.
    # @return [void]
    def DisplayWarnings(display, timeout)
      @display_warnings = display
      @timeout_warnings = timeout
      nil
    end

    # Message popup dialog can be displayed immediately when a new message  is stored.
    #
    # This function enables or diables popuping of dialogs.
    #
    # @param [Boolean] display if true then display message popups immediately
    # @param [Fixnum] timeout dialog is automatically closed after timeout seconds. Value 0 means no time out, dialog will be closed only by user.
    # @return [void]

    def DisplayMessages(display, timeout)
      @display_messages = display
      @timeout_messages = timeout
      nil
    end

    # Yes/No Message popup dialog can be displayed immediately when a new message  is stored.
    #
    # This function enables or diables popuping of dialogs.
    #
    # @param [Boolean] display if true then display message popups immediately
    # @param [Fixnum] timeout dialog is automatically closed after timeout seconds. Value 0 means no time out, dialog will be closed only by user.
    # @return [void]

    def DisplayYesNoMessages(display, timeout)
      @display_yesno_messages = display
      @timeout_yesno_messages = timeout
      nil
    end

    # Set warnings logging to .y2log file
    # @param [Boolean] log if log is true then warning messages will be logged
    # @return [void]
    def LogWarnings(log)
      @log_warnings = log

      nil
    end

    # Set yes/no messages logging to .y2log file
    # @param [Boolean] log if log is true then  messages will be logged
    # @return [void]
    def LogYesNoMessages(log)
      @log_yesno_messages = log

      nil
    end

    # Set messages logging to .y2log file
    # @param [Boolean] log if log is true then  messages will be logged
    # @return [void]
    def LogMessages(log)
      @log_messages = log

      nil
    end

    # Set warnings logging to .y2log file
    # @param [Boolean] log if log is true then warning messages will be logged
    # @return [void]
    def LogErrors(log)
      @log_errors = log

      nil
    end

    # Create rich text string from stored warning, message or error messages.
    #
    # Every new line character "\n" is replaced by string "[BR]".
    #
    # @param [Boolean] w include warnings in returned string
    # @param [Boolean] e include errors in returned string
    # @param [Boolean] m include messages in returned string
    # @param [Boolean] ynm include Yes/No messages in returned string
    # @return [String] rich text string
    def GetMessages(w, e, m, ynm)
      richtext = ""

      if w
        # translators: warnings summary header
        richtext = Ops.add(
          Ops.add(Ops.add(richtext, "<P><B>"), _("Warning:")),
          "</B><BR>"
        )

        Builtins.foreach(@warnings) do |s|
          strs = Builtins.splitstring(s, "\n")
          Builtins.foreach(strs) do |line|
            richtext = Ops.add(Ops.add(richtext, line), "<BR>")
          end
        end

        richtext = Ops.add(richtext, "</P>")
      end

      if e
        # translators: errors summary header
        richtext = Ops.add(
          Ops.add(Ops.add(richtext, "<P><B>"), _("Error:")),
          "</B><BR>"
        )

        Builtins.foreach(@errors) do |s|
          strs = Builtins.splitstring(s, "\n")
          Builtins.foreach(strs) do |line|
            richtext = Ops.add(Ops.add(richtext, line), "<BR>")
          end
        end

        richtext = Ops.add(richtext, "</P>")
      end

      if m
        # translators: message summary header
        richtext = Ops.add(
          Ops.add(Ops.add(richtext, "<P><B>"), _("Message:")),
          "</B><BR>"
        )

        Builtins.foreach(@messages) do |s|
          strs = Builtins.splitstring(s, "\n")
          Builtins.foreach(strs) do |line|
            richtext = Ops.add(Ops.add(richtext, line), "<BR>")
          end
        end

        richtext = Ops.add(richtext, "</P>")
      end

      if ynm
        # translators: message summary header
        richtext = Ops.add(
          Ops.add(Ops.add(richtext, "<P><B>"), _("Message:")),
          "</B><BR>"
        )

        Builtins.foreach(@yesno_messages) do |s|
          strs = Builtins.splitstring(s, "\n")
          Builtins.foreach(strs) do |line|
            richtext = Ops.add(Ops.add(richtext, line), "<BR>")
          end
        end

        richtext = Ops.add(richtext, "</P>")
      end
      richtext
    end

    publish variable: :message_settings, type: "map"
    publish variable: :error_settings, type: "map"
    publish variable: :warning_settings, type: "map"
    publish variable: :yesno_message_settings, type: "map"
    publish variable: :modified, type: "boolean"
    publish function: :SetModified, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish function: :Summary, type: "string ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :Export, type: "map ()"
    publish function: :ClearYesNoMessages, type: "void ()"
    publish function: :ClearMessages, type: "void ()"
    publish function: :ClearErrors, type: "void ()"
    publish function: :ClearWarnings, type: "void ()"
    publish function: :ClearAll, type: "void ()"
    publish function: :NumYesNoMessages, type: "integer ()"
    publish function: :NumMessages, type: "integer ()"
    publish function: :NumWarnings, type: "integer ()"
    publish function: :NumErrors, type: "integer ()"
    publish function: :AnyQuestion, type: "boolean (string, string, string, string, symbol)"
    publish function: :ErrorAnyQuestion, type: "boolean (string, string, string, string, symbol)"
    publish function: :Message, type: "void (string)"
    publish function: :LongMessage, type: "void (string)"
    publish function: :ShowText, type: "void (string, string)"
    publish function: :Warning, type: "void (string)"
    publish function: :LongWarning, type: "void (string)"
    publish function: :Error, type: "void (string)"
    publish function: :LongError, type: "void (string)"
    publish function: :DisplayErrors, type: "void (boolean, integer)"
    publish function: :DisplayWarnings, type: "void (boolean, integer)"
    publish function: :DisplayMessages, type: "void (boolean, integer)"
    publish function: :DisplayYesNoMessages, type: "void (boolean, integer)"
    publish function: :LogWarnings, type: "void (boolean)"
    publish function: :LogYesNoMessages, type: "void (boolean)"
    publish function: :LogMessages, type: "void (boolean)"
    publish function: :LogErrors, type: "void (boolean)"
    publish function: :GetMessages, type: "string (boolean, boolean, boolean, boolean)"
  end

  Report = ReportClass.new
  Report.main
end
