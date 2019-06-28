# typed: true
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
# Bad Popup design: Default button order exchanged
#
# DON'T DO THIS!
module Yast
  class AskShowInstallationLogBadClient < Client
    def main
      Yast.import "Popup"
      Yast.import "Label"

      @dont_do_it = Popup.AnyQuestion(
        Popup.NoHeadline,
        "Show installation log?",
        Label.NoButton,
        Label.YesButton,
        :no
      ) # button role reversed - "Yes"

      nil
    end
  end
end

Yast::AskShowInstallationLogBadClient.new.main
