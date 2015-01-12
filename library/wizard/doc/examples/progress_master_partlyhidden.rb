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
  class ProgressMasterPartlyhiddenClient < Client
    def main
      # call progress_client1 and progress_client2
      # progress_client2 call is partly hidden - the detailed progress of progress_client2 is hidden from UI

      Yast.import "Progress"
      Yast.import "Wizard"

      @wait = 200

      Wizard.CreateDialog

      # crate a progress with 10 steps
      Progress.New(
        "Progress Example (display a nested progress)",
        "",
        2,
        ["Calling ./progress_client1.ycp", "Calling ./progress_client2.ycp"],
        [],
        ""
      )

      Progress.NextStage
      WFM.CallFunction("./progress_client1.ycp", ["noinit"])

      Progress.NextStage

      @p = Progress.set(false)
      WFM.CallFunction("./progress_client2.ycp", ["noinit"])
      Progress.set(@p)

      Builtins.sleep(@wait)
      Progress.Finish

      Builtins.sleep(@wait)
      Wizard.CloseDialog

      nil
    end
  end
end

Yast::ProgressMasterPartlyhiddenClient.new.main
