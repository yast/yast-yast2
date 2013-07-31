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
# File:	clients/remotechooser.ycp
# Package:	yast2
# Summary:	Remote administration client
# Authors:	Michal Svec <msvec@suse.cz>
#
# $Id$
module Yast
  class RemotechooserClient < Client
    def main
      Yast.import "UI"

      textdomain "base"
      Yast.import "Label"

      @host = "localhost"
      @user = ""
      @modul = "menu"
      @protocol = "ssh"

      @hosts = []


      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Remote chooser module started")

      # Label text
      UI.OpenDialog(Label(_("Scanning for hosts in the local network...")))
      @hosts = Builtins.sort(Convert.to_list(SCR.Read(path(".net.hostnames"))))
      @hosts = [] if @hosts == nil
      UI.CloseDialog

      # Get the current user name
      @output = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "echo \"$USER\"")
      )
      @user = Ops.get(
        Builtins.splitstring(Ops.get_string(@output, "stdout", ""), "\n"),
        0,
        ""
      )

      @ret = nil
      while true
        @ret = ChooseDialog()

        if @ret == :abort || @ret == :cancel || @ret == :back
          break
        # Launch it
        elsif @ret == :next
          @launch = Ops.add(Ops.add(@protocol, "://"), @user)
          if @protocol != "su" && @protocol != "sudo"
            @launch = Ops.add(Ops.add(@launch, "@"), @host)
          end
          @launch = Ops.add(Ops.add(@launch, "/"), @modul)

          Builtins.y2milestone("Launching %1", @launch)
          WFM.CallFunction(@launch, [])
          next
        else
          Builtins.y2error("Unexpected return code: %1", @ret)
          next
        end
      end

      Builtins.y2milestone("Remote chooser module finished")
      Builtins.y2milestone("----------------------------------------") 

      # EOF

      nil
    end

    def ChooseDialog
      # `Left(`HSquash(`RadioButtonGroup(`id(`protocol),
      # 	  `VBox(
      # 	      `Left(`RadioButton(`id("telnet"), "telnet", true)),
      # 	      `Left(`RadioButton(`id("rlogin"), "rlogin")),
      # 	      `Left(`RadioButton(`id("rsh"),    "rsh")),
      # 	      `Left(`RadioButton(`id("ssh"),    "ssh")),
      # 	      `Left(`RadioButton(`id("su"),     "su")),
      # 	      `Left(`RadioButton(`id("sudo"),   "sudo"))))));

      contents = VBox(
        HSpacing(50),
        HBox(
          # SelectionBox label
          SelectionBox(Id(:hosts), Opt(:notify), _("&Available Hosts:"), @hosts),
          HSpacing(1.0),
          VBox(
            # TextEntry label
            TextEntry(Id(:host), _("&Host:"), @host),
            # TextEntry label
            TextEntry(Id(:user), _("&User name:"), @user),
            # TextEntry label
            TextEntry(Id(:modul), _("&Module to Start:"), @modul),
            # ComboBox label
            Left(
              ComboBox(
                Id(:protocol),
                _("Connection &Protocol:"),
                [
                  Item(Id("ssh"), "ssh", @protocol == "ssh"),
                  Item(Id("rsh"), "rsh", @protocol == "rsh"),
                  Item(Id("rlogin"), "rlogin", @protocol == "rlogin"),
                  Item(Id("telnet"), "telnet", @protocol == "telnet"),
                  Item(Id("sudo"), "sudo", @protocol == "sudo"),
                  Item(Id("su"), "su", @protocol == "su")
                ]
              )
            ),
            # `VCenter(ProtocolSelection()),
            VSpacing(1),
            HBox(
              # PushButton label
              PushButton(Id(:next), Opt(:default), _("&Launch")),
              HStretch(),
              PushButton(Id(:cancel), Label.CancelButton)
            )
          )
        )
      )

      UI.OpenDialog(contents)

      ret = nil
      while true
        ret = UI.UserInput

        if ret == :abort || ret == :cancel
          # if(ReallyAbort()) break;
          # else continue;
          break
        elsif ret == :hosts
          UI.ChangeWidget(
            Id(:host),
            :Value,
            UI.QueryWidget(Id(:hosts), :CurrentItem)
          )
          next
        elsif ret == :back
          break
        elsif ret == :next
          # FIXME check_*
          break
        else
          Builtins.y2error("Unexpected return code: %1", ret)
          next
        end
      end

      if ret == :next
        @protocol = Convert.to_string(UI.QueryWidget(Id(:protocol), :Value))
        @modul = Convert.to_string(UI.QueryWidget(Id(:modul), :Value))
        @user = Convert.to_string(UI.QueryWidget(Id(:user), :Value))
        @host = Convert.to_string(UI.QueryWidget(Id(:host), :Value))

        @host = "localhost" if @host == ""
        @modul = "menu" if @modul == ""
      end

      UI.CloseDialog
      deep_copy(ret)
    end
  end
end

Yast::RemotechooserClient.new.main
