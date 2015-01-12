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
# Trivial popups example
#
# Author: Stefan Hundhammer <sh@suse.de>
#
# $Id$
module Yast
  class Popups1Client < Client
    def main
      Yast.import "UI"
      Yast.import "Label"
      Yast.import "Popup"

      UI.OpenDialog(
        VBox(
          PushButton(Id(:msg), Opt(:hstretch), "&Message Popup"),
          PushButton(Id(:notify), Opt(:hstretch), "&Notify Popup"),
          PushButton(Id(:warn), Opt(:hstretch), "&Warning Popup"),
          PushButton(Id(:err), Opt(:hstretch), "&Error Popup"),
          PushButton(Id(:timed_msg), Opt(:hstretch), "&Timed Message Popup"),
          PushButton(Id(:timed_warn), Opt(:hstretch), "Ti&med WarningPopup"),
          PushButton(Id(:timed_err), Opt(:hstretch), "T&imed Error Popup"),
          PushButton(Id(:yesNo), Opt(:hstretch), "&Yes / No Popup"),
          PushButton(
            Id(:contCancel),
            Opt(:hstretch),
            "C&ontinue / Cancel Popup"
          ),
          PushButton(
            Id(:abort),
            Opt(:hstretch),
            "Confirm &Abort Popup (no changes)"
          ),
          PushButton(
            Id(:abort_ch),
            Opt(:hstretch),
            "Confirm Abort Popup (&with changes)"
          ),
          PushButton(Id(:show_file), Opt(:hstretch), "Show &File Popup"),
          PushButton(Id(:show_text), Opt(:hstretch), "Show Te&xt Popup"),
          VSpacing(),
          PushButton(Id(:close), Label.CloseButton)
        )
      )

      @button_id = :dummy
      @ok = false
      loop do
        @button_id = Convert.to_symbol(UI.UserInput)

        if @button_id == :msg
          Popup.Message("Hello, world!")
        elsif @button_id == :notify
          Popup.Notify("Notify the world!")
        elsif @button_id == :warn
          Popup.Warning("This is the only world we have!")
        elsif @button_id == :err
          Popup.Error("Cannot delete world -\nthis is the only world we have!")
        elsif @button_id == :timed_msg
          Popup.TimedMessage("Just some seconds left to save the world...", 20)
        elsif @button_id == :timed_warn
          Popup.TimedWarning("Time is running out to save the world...", 20)
        elsif @button_id == :timed_err
          Popup.TimedError("This world will be deleted...", 20)
        elsif @button_id == :yesNo
          @ok = Popup.YesNo("Really delete world?")
        elsif @button_id == :contCancel
          @ok = Popup.ContinueCancel("World will be deleted.")
        elsif @button_id == :abort
          @ok = Popup.ReallyAbort(false)
        elsif @button_id == :abort_ch
          @ok = Popup.ReallyAbort(true)
        elsif @button_id == :show_file
          Popup.ShowFile("Boot Messages", "/var/log/boot.msg")
        elsif @button_id == :show_text
          @text = Convert.to_string(
            SCR.Read(path(".target.string"), "/var/log/boot.msg")
          )
          Popup.ShowText("Boot Messages", @text)
        end
        break if @button_id == :close
      end

      UI.CloseDialog

      nil
    end
  end
end

Yast::Popups1Client.new.main
