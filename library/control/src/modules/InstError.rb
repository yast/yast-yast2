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
# File:	modules/InstError.ycp
# Package:	Installation
# Summary:	Module for reporting installation errors
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# $Id$
#
# This module provides unified interface for reporting
# installation errors.
require "yast"

module Yast
  class InstErrorClass < Module
    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "Icon"
      Yast.import "Label"
      Yast.import "String"
      Yast.import "Report"
    end

    def SaveLogs
      cmd = Convert.to_map(
        WFM.Execute(path(".local.bash_output"), "echo ${HOME}")
      )
      homedir = "/"

      if Ops.get_integer(cmd, "exit", -1) == 0
        homedir = Ops.get(
          Builtins.splitstring(Ops.get_string(cmd, "stdout", "/"), "\n"),
          0,
          "/"
        )
        homedir = "/" if homedir == ""
      else
        Builtins.y2warning(
          "Unable to find out home dir: %1, using %2",
          cmd,
          homedir
        )
      end
      homedir = Builtins.sformat("%1/y2logs.tgz", homedir)

      savelogsto = UI.AskForSaveFileName(
        homedir,
        "*.tgz *.tar.gz *.tar.bz2",
        _("Save y2logs to...")
      )

      return nil if savelogsto.nil?

      # Busy message, %1 is replaced with a filename
      UI.OpenDialog(
        Label(Builtins.sformat(_("Saving YaST logs to %1..."), savelogsto))
      )
      Builtins.y2milestone("Saving YaST logs to: %1", savelogsto)

      cmd = Convert.to_map(
        WFM.Execute(
          path(".local.bash_output"),
          Builtins.sformat("save_y2logs '%1'", String.Quote(savelogsto))
        )
      )
      dialog_ret = nil

      if Ops.get_integer(cmd, "exit", -1) != 0
        Builtins.y2error("Unable to save logs to %1", savelogsto)

        Report.Error(
          Builtins.sformat(
            # Error message, %1 is replaced with a filename
            # %2 with am error reason (there is a newline between %1 and %2)
            _("Unable to save YaST logs to %1\n%2"),
            savelogsto,
            Ops.get_string(cmd, "stderr", "")
          )
        )

        dialog_ret = false
      else
        Builtins.y2milestone("Logs have been saved to: %1", savelogsto)
        dialog_ret = true
      end

      UI.CloseDialog

      dialog_ret
    end

    # Function opens a pop-up error message (defined by the parameters).
    # Reports where to report a bug and which logs to attach.
    # It additionally offers to save logs directly from the dialog.
    #
    # @param [String] heading
    # @param [String] error_text
    # @param [String] details (displayed as a plain text, can contain multiple lines)
    def ShowErrorPopUp(heading, error_text, details)
      success = UI.OpenDialog(
        Opt(:decorated, :warncolor),
        VBox(
          Left(HBox(HSquash(MarginBox(0.5, 0.2, Icon.Error)), Heading(heading))),
          MarginBox(
            1,
            0.5,
            VBox(
              Left(Label(error_text)),
              # `VSpacing (1),
              Left(
                if details.nil?
                  Label(
                    Builtins.sformat(
                      # TRANSLATORS: part of an error message
                      # // %1 - logfile, possibly with errors
                      _(
                        "More information can be found near the end of the '%1' file."
                      ),
                      "/var/log/YaST2/y2log"
                    )
                  )
                else
                  MinSize(80, 10, RichText(Opt(:plainText, :hstretch), details))
                end
              ),
              # `VSpacing (1),
              Left(
                Label(
                  Builtins.sformat(
                    # TRANSLATORS: part of an error message
                    # %1 - link to our bugzilla
                    # %2 - directory where YaST logs are stored
                    # %3 - link to the Yast Bug Reporting HOWTO Web page
                    _(
                      "This is worth reporting a bug at %1.\n" \
                        "Please, attach also all YaST logs stored in the '%2' directory.\n" \
                        "See %3 for more information about YaST logs."
                    ),
                    "http://bugzilla.suse.com/",
                    "/var/log/YaST2/",
                    # link to the Yast Bug Reporting HOWTO
                    # for translators: use the localized page for your language if it exists,
                    # check the combo box "In other laguages" on top of the page
                    _("http://en.opensuse.org/Bugs/YaST")
                  )
                )
              )
            )
          ),
          ButtonBox(
            # FIXME: BNC #422612, Use `opt(`noSanityCheck) later
            PushButton(
              Id(:save_y2logs),
              Opt(:cancelButton),
              _("&Save YaST Logs...")
            ),
            PushButton(Id(:ok), Opt(:key_F10), Label.OKButton)
          )
        )
      )

      if success != true
        Builtins.y2error(
          "Cannot open a dialog: %1/%2/%3",
          heading,
          error_text,
          details
        )
        return
      end

      loop do
        uret = UI.UserInput

        break if uret != :save_y2logs

        SaveLogs()
      end

      UI.CloseDialog

      nil
    end

    # Function is similar to ShowErrorPopUp but the error details are grabbed automatically
    # from YaST logs.
    #
    # @param [String] error_text (e.g., "Client inst_abc returned invalid data.")
    def ShowErrorPopupWithLogs(error_text)
      cmd = Convert.to_map(
        WFM.Execute(
          path(".local.bash_output"),
          "tail -n 200 /var/log/YaST2/y2log | grep ' <\\(3\\|5\\)> '"
        )
      )

      details = cmd["stdout"] if cmd["exit"] == 0 && !cmd["stdout"].empty?
      ShowErrorPopUp(
        _("Installation Error"),
        error_text,
        details
      )

      nil
    end

    publish function: :ShowErrorPopUp, type: "void (string, string, string)"
    publish function: :ShowErrorPopupWithLogs, type: "void (string)"
  end

  InstError = InstErrorClass.new
  InstError.main
end
