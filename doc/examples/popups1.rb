# typed: false
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

        case @button_id
        when :msg
          Popup.Message("Hello, world!")
        when :notify
          Popup.Notify("Notify the world!")
        when :warn
          Popup.Warning("This is the only world we have!")
        when :err
          Popup.Error("Cannot delete world -\nthis is the only world we have!")
        when :timed_msg
          Popup.TimedMessage("Just some seconds left to save the world...", 20)
        when :timed_warn
          Popup.TimedWarning("Time is running out to save the world...", 20)
        when :timed_err
          Popup.TimedError("This world will be deleted...", 20)
        when :yesNo
          @ok = Popup.YesNo("Really delete world?")
        when :contCancel
          @ok = Popup.ContinueCancel("World will be deleted.")
        when :abort
          @ok = Popup.ReallyAbort(false)
        when :abort_ch
          @ok = Popup.ReallyAbort(true)
        when :show_file
          Popup.ShowFile("Boot Messages", "/var/log/boot.msg")
        when :show_text
          @text = Convert.to_string(
            SCR.Read(path(".target.string"), "/var/log/boot.msg")
          )
          Popup.ShowText("Boot Messages", @text)
        when :close
          break
        end
      end

      UI.CloseDialog

      nil
    end
  end
end

Yast::Popups1Client.new.main
