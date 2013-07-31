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
  class ProgressClient2Client < Client
    def main

      # an example client which uses Progress::

      Yast.import "Progress"
      Yast.import "Wizard"

      @wait = 200

      Wizard.CreateDialog if WFM.Args != ["noinit"]

      # crate a progress with 10 steps
      Progress.New(
        "Progress Example 2 (10 steps in 2 stages)",
        "",
        10,
        ["Stage 1", "Stage 2"],
        [],
        ""
      )

      Builtins.sleep(@wait)
      Progress.NextStage

      Builtins.sleep(@wait)
      Progress.NextStep

      Builtins.sleep(@wait)
      Progress.NextStep

      Builtins.sleep(@wait)
      Progress.NextStep

      Builtins.sleep(@wait)
      Progress.NextStage

      Builtins.sleep(@wait)
      Progress.NextStep

      Builtins.sleep(@wait)
      Progress.NextStep

      Builtins.sleep(@wait)
      Progress.NextStep

      Builtins.sleep(@wait)
      Progress.NextStep

      Builtins.sleep(@wait)
      Progress.NextStep

      Builtins.sleep(@wait)
      Progress.Finish

      Builtins.sleep(@wait)
      Wizard.CloseDialog if WFM.Args != ["noinit"]

      nil
    end
  end
end

Yast::ProgressClient2Client.new.main
