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
# File:        modules/ALog.ycp
# Package:     YaST2
# Summary:     Admin's Log, producing a summary of what YaST did to the system
# Authors:     Martin Vidner <mvidner@suse.cz>
#
# FATE#303700
# TODO: stability tag.
#
# <pre>
# ALog::Item("/etc/ntp.conf: added 'server ntp.example.org'");
# ALog::Item("enabled /etd/init.d/ntp");
# ALog::Item("started /etd/init.d/ntp");
#
# ALog::CommitPopup();
#   ALog::Note("set up ntp from local server");
# </pre>
require "yast"

module Yast
  class ALogClass < Module
    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "Label"
    end

    def doLog(type, msg)
      # TODO: make a separate log, this is just a prototype
      Builtins.y2internal("{%1} %2", type, msg)

      nil
    end

    # Log a change to the system from the system point of view.
    # msg should include the file being changed, and what changes are made
    # (TODO: with all detail? or summary?)
    # Example "/etc/ntp.conf: added 'server ntp.example.org'"
    # @param [String] msg message
    def Item(msg)
      doLog("item", msg)

      nil
    end

    # Log a change to the system from the human point of view.
    # (It will appear slightly differently in the log)
    # Example "get proper time from the corporate time server
    #         as requested in ticket bofh#327"
    # @param [String] msg message
    def Note(msg)
      doLog("note", msg)

      nil
    end

    def uiInput(label)
      # TODO: more lines?
      d = VBox(
        InputField(Id(:val), label, ""),
        ButtonBox(
          PushButton(
            Id(:ok),
            Opt(:default, :key_F10, :okButton),
            Label.OKButton
          )
        )
      )
      UI.OpenDialog(d)
      ui = nil
      ui = UI.UserInput while ui != :ok || ui != :cancel

      val = nil
      val = Convert.to_string(UI.QueryWidget(Id(:val), :Value)) if ui == :ok
      val
    end

    # Prompt the user for a message to describe the changes
    # that she did using YaST, logs it using {#Note}
    def CommitPopup
      i = uiInput(_("Enter a log message that describes the changes you made."))
      msg = i.nil? ? "*empty log message*" : i
      Note(msg)

      nil
    end

    publish function: :Item, type: "void (string)"
    publish function: :Note, type: "void (string)"
    publish function: :CommitPopup, type: "void ()"
  end

  ALog = ALogClass.new
  ALog.main
end
