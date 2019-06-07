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
# Popups example concerning installation
#
# Author:	Arvin Schnell <arvin@suse.de>
#
# $Id$
module Yast
  class Popups3Client < Client
    def main
      Yast.import "UI"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Mode"

      UI.OpenDialog(
        VBox(
          PushButton(Id(:painless), Opt(:hstretch), "Confirm Abort (painless)"),
          PushButton(
            Id(:incomplete),
            Opt(:hstretch),
            "Confirm Abort (incomplete)"
          ),
          PushButton(Id(:unusable), Opt(:hstretch), "Confirm Abort (unusable)"),
          PushButton(Id(:error), Opt(:hstretch), "Module Error"),
          PushButton(Id(:close), Label.CloseButton)
        )
      )

      @button_id = :dummy
      loop do
        @button_id = Convert.to_symbol(UI.UserInput)

        case @button_id
        when :painless
          Popup.ConfirmAbort(:painless)
        when :incomplete
          Popup.ConfirmAbort(:incomplete)
        when :unusable
          Popup.ConfirmAbort(:unusable)
        when :error
          Popup.ModuleError("The module inst_games.ycp does not work.")
        when :close
          break
        end
      end

      UI.CloseDialog

      nil
    end
  end
end

Yast::Popups3Client.new.main
