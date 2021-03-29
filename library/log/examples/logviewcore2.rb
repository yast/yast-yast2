# typed: false
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
module Yast
  class Logviewcore2Client < Client
    def main
      Yast.import "UI"
      Yast.import "LogViewCore"

      @file = "/var/log/messages"
      @grep = "conf"

      UI.OpenDialog(
        VBox(
          Left(Heading("Log")),
          LogView(
            Id(:log),
            Builtins.sformat("Content of %1 grepped with %2:", @file, @grep),
            10,
            100
          ),
          PushButton(Id(:close), "Close")
        )
      )

      LogViewCore.Start(Id(:log), "file" => @file, "grep" => @grep)

      loop do
        @widget = UI.TimeoutUserInput(250)

        if @widget == :timeout
          LogViewCore.Update(Id(:log))
        elsif @widget == :close
          break
        end
      end

      LogViewCore.Stop

      nil
    end
  end
end

Yast::Logviewcore2Client.new.main
