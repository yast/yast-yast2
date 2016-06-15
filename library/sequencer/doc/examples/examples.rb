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
  class ExamplesClient < Client
    def main
      Yast.import "UI"

      nil
    end

    def Aliases
      aliases = {
        "begin"        => ->() { BeginDialog() },
        "end"          => ->() { EndDialog() },
        "config"       => ->() { ConfigDialog() },
        "details"      => ->() { DetailsDialog() },
        "superdetails" => ->() { SuperDetailsDialog() },
        "expert"       => ->() { ExpertDialog() },
        "expert2"      => ->() { Expert2Dialog() },
        "decide"       => [->() { Decide() }, true]
      }
      deep_copy(aliases)
    end

    def GUI(text, buttons)
      buttons = deep_copy(buttons)
      i = 0
      t = HBox()
      buttons_map = {
        back:    "Back",
        next:    "Next",
        finish:  "Finish",
        details: "Details",
        expert:  "Expert",
        yes:     "Yes",
        no:      "No",
        ok:      "OK"
      }
      while Ops.less_than(i, Builtins.size(buttons))
        b = Ops.get_string(buttons_map, Ops.get(buttons, i), "-")
        t = if b == "-"
          Builtins.add(t, PushButton(b))
            else
          Builtins.add(t, PushButton(Id(Ops.get(buttons, i)), b))
        end
        i = Ops.add(i, 1)
      end

      UI.OpenDialog(VBox(Label(text), t))
      ret = UI.UserInput
      UI.CloseDialog
      deep_copy(ret)
    end
  end
end

Yast::ExamplesClient.new.main
