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
module Yast
  class Logview4Client < Client
    def main
      Yast.import "UI"
      Yast.import "LogView"

      LogView.Display(

          "file"    => "/var/log/messages",
          "grep"    => "conf",
          "save"    => true,
          "actions" => [["Jump", fun_ref(method(:Jump), "void ()")]]

      )

      nil
    end

    def Jump
      UI.OpenDialog(Opt(:decorated), VBox(MarginBox(2, 2, PushButton("Close"))))
      UI.UserInput
      UI.CloseDialog

      nil
    end
  end
end

Yast::Logview4Client.new.main
