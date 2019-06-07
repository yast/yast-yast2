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
# Example how NOT to use popups:
#
# - The headline is redundant
#
# - The text is too verbose
#
# - The text contains a reference to "YaST2"
#   (the user shouldn't need to know what that is)
module Yast
  class AskCreateBackupBadClient < Client
    def main
      Yast.import "Popup"

      @answer = Popup.YesNoHeadline(
        "Create Backup?", # superfluous headline
        "Should YaST2 create a backup of the configuration files?"
      )

      nil
    end
  end
end

Yast::AskCreateBackupBadClient.new.main
