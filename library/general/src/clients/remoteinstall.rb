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
# File:	clients/remoteinstall.ycp
# Package:	yast2
# Summary:	Remote installation client
# Authors:	Michal Svec <msvec@suse.cz>
#
# $Id$
module Yast
  class RemoteinstallClient < Client
    def main
      Yast.import "UI"

      textdomain "base"
      Yast.import "Label"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Remote installation module started")

      @device = ""
      # Initialize the serial device
      @device = Convert.to_string(
        SCR.Read(path(".sysconfig.mouse.MOUSEDEVICE"))
      )
      if @device == "/dev/ttyS0"
        @device = "/dev/ttyS1"
      else
        @device = "/dev/ttyS0"
      end
      Builtins.y2debug("device=%1", @device)

      # Dialog contents
      @contents = HBox(
        HSpacing(1),
        VBox(
          VSpacing(0.2),
          # ComboBox label
          ComboBox(
            Id(:device),
            Opt(:editable),
            _("Select the Serial &Interface to Use:"),
            [
              Item(Id("/dev/ttyS0"), "/dev/ttyS0", @device == "/dev/ttyS0"),
              Item(Id("/dev/ttyS1"), "/dev/ttyS1", @device == "/dev/ttyS1")
            ]
          ),
          VSpacing(1),
          HBox(
            # PushButton label
            PushButton(Id(:next), Opt(:default), _("&Launch")),
            HStretch(),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        ),
        HSpacing(1)
      )

      UI.OpenDialog(@contents)
      UI.SetFocus(Id(:device))

      # Main cycle
      @ret = nil
      while true
        @ret = UI.UserInput

        if @ret == :abort || @ret == :cancel || @ret == :back
          # if(ReallyAbort()) break;
          # else continue;
          break
        elsif @ret == :next
          # FIXME check_* device!="" and device exists
          break
        else
          Builtins.y2error("Unexpected return code: %1", @ret)
          next
        end
      end

      @device = Convert.to_string(UI.QueryWidget(Id(:device), :Value))
      UI.CloseDialog

      if @ret == :next
        @modulename = Ops.add("serial(115200):", @device)
        Builtins.y2debug("modulename=%1", @modulename)
        WFM.CallFunction(@modulename, [])
      end

      Builtins.y2milestone("Remote installation module finished")
      Builtins.y2milestone("----------------------------------------") 

      # EOF

      nil
    end
  end
end

Yast::RemoteinstallClient.new.main
