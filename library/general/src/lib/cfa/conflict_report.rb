# Copyright (c) [2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"

Yast.import "Report"

module CFA
  # Class for showing conflicts.
  class ConfictReport
    include Yast::Logger
    include Yast::I18n
    extend Yast::I18n

    # Popup which shows the conflicting files and their attributes.
    #
    # @param conflicts [Hash<String, Array<String>>] conflicting filepath with the
    #                                                corresponding array of entry names.
    def self.report(conflicts)
      textdomain "base"
      return if !conflicts || conflicts.empty?

      text = ""
      text << _("Changed values have conflicts with:<br><br>")
      conflicts.each do |filename, conflict|
        text << (_("File: %s<br>") % filename)
        text << (_("Conflicting entries: %s<br>") % conflict.join(", "))
        text << "<br>"
      end
      text << _("You will have to adapt these entries manually in order to set your changes.")
      Yast::Report.LongWarning(text)
    end
  end
end
