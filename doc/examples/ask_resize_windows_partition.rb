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
# Example when to use a headline:
#
# There is lengthy text that advanced users might have read several times
# before, so we give him a concise headline that identifies that dialog so he
# can keep on working without having to read everything again.
module Yast
  class AskResizeWindowsPartitionClient < Client
    def main
      Yast.import "Popup"

      @long_text = "Resizing the windows partition works well in most cases,\n" \
        "but there are pathological cases where this might fail.\n" \
        "\n" \
        "You might lose all data on that disk. So please make sure\n" \
        "you have an up-to-date backup of all relevant data\n" \
        "for disaster recovery.\n" \
        "\n" \
        "If you are unsure, it might be a good idea to abort the installation\n" \
        "right now and make a backup."

      @answer = Popup.YesNoHeadline("Resize Windows Partition?", @long_text)

      nil
    end
  end
end

Yast::AskResizeWindowsPartitionClient.new.main
