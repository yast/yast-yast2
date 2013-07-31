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
# File:	clients/password.ycp
# Package:	yast2
# Summary:	Ask user for password
# Authors:	Michal Svec <msvec@suse.cz>
#
# $Id$
#
# Return the password, if user entered one.
# Return nil, if user canceled or closed the window.
module Yast
  class PasswordClient < Client
    def main
      Yast.import "UI"

      textdomain "base"
      Yast.import "Label"

      @contents = VBox(
        # TextEntry label
        Password(Id(:pw), _("&Enter Password:")),
        HBox(
          PushButton(Id(:ok), Opt(:hstretch, :default), Label.OKButton),
          PushButton(Id(:cancel), Opt(:hstretch), Label.CancelButton)
        )
      )

      UI.OpenDialog(@contents)
      UI.SetFocus(Id(:pw))
      @ret = nil
      if UI.UserInput == :ok
        @ret = Convert.to_string(UI.QueryWidget(Id(:pw), :Value))
      end
      UI.CloseDialog
      @ret 

      # EOF
    end
  end
end

Yast::PasswordClient.new.main
