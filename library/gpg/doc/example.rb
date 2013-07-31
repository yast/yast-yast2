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
# This is an example file for GPG.ycp and GPGWidgets.ycp modules.
module Yast
  class ExampleClient < Client
    def main
      Yast.import "UI"

      Yast.import "GPG"
      Yast.import "GPGWidgets"
      Yast.import "CWM"

      Builtins.y2milestone("PrivateKeys: %1", GPG.PrivateKeys)
      Builtins.y2milestone("PublicKeys: %1", GPG.PublicKeys)

      @w = CWM.CreateWidgets(
        ["select_private_key", "create_new_key"],
        GPGWidgets.Widgets
      )

      # create a popup window from the widgets
      @contents = HBox(
        VSpacing(15),
        VBox(
          HSpacing(70),
          # label
          Heading("Select the Private Key"),
          "select_private_key",
          "create_new_key",
          VSpacing(1),
          PushButton(Id(:ok), "OK")
        )
      )

      @contents = CWM.PrepareDialog(@contents, @w)

      UI.OpenDialog(@contents)
      @ret = CWM.Run(@w, {})
      Builtins.y2milestone("Ret: %1", @ret)
      UI.CloseDialog

      @selected_key = GPGWidgets.SelectedPrivateKey

      Builtins.y2milestone("SelectedPrivateKey: %1", @selected_key)

      if @selected_key != nil && @selected_key != ""
        GPGWidgets.AskPassphrasePopup(GPGWidgets.SelectedPrivateKey)
      end

      nil
    end
  end
end

Yast::ExampleClient.new.main
