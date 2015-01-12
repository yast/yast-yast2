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
        "begin"        => lambda { BeginDialog() },
        "end"          => lambda { EndDialog() },
        "config"       => lambda { ConfigDialog() },
        "details"      => lambda { DetailsDialog() },
        "superdetails" => lambda { SuperDetailsDialog() },
        "expert"       => lambda { ExpertDialog() },
        "expert2"      => lambda { Expert2Dialog() },
        "decide"       => [lambda { Decide() }, true]
      }
      deep_copy(aliases)
    end

    def GUI(text, buttons)
      buttons = deep_copy(buttons)
      i = 0
      t = HBox()
      _Buttons = {
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
        _B = Ops.get_string(_Buttons, Ops.get(buttons, i), "-")
        if _B == "-"
          t = Builtins.add(t, PushButton(_B))
        else
          t = Builtins.add(t, PushButton(Id(Ops.get(buttons, i)), _B))
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
