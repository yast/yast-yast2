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
# File:  ContextMenu.ycp
# Package:  yast2
# Summary:  UI ContextMenu Helper
# Authors:  Arvin Schnell <aschnell@suse.de>
require "yast"

module Yast
  class ContextMenuClass < Module
    def main
      Yast.import "UI"
    end

    def Simple(items)
      items = deep_copy(items)
      UI.OpenContextMenu(term(:menu, items))

      Convert.to_symbol(UI.UserInput)
    end

    publish function: :Simple, type: "symbol (list <term>)"
  end

  ContextMenu = ContextMenuClass.new
  ContextMenu.main
end
