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
  class ProgressMasterHiddenClient < Client
    def main
      # call progress_client1 and progress_client2
      # progress_client2 call is completely hidden from UI

      Yast.import "Progress"
      Yast.import "Wizard"

      @wait = 200

      Wizard.CreateDialog

      Progress.New(
        "Progress Example (display a nested progress)",
        "",
        1,
        ["Calling ./progress_client1.ycp"],
        [],
        ""
      )

      Progress.NextStage
      WFM.CallFunction("./progress_client1.ycp", ["noinit"])

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

Yast::ProgressMasterHiddenClient.new.main
