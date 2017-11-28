# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "yast"
require "y2firewall/firewalld/api"

module Y2Firewall
  class Firewalld
    # Class to work with Firewalld zones
    class Zone
      include Yast::I18n
      extend Yast::I18n
      # Map of known zone names and description
      KNOWN_ZONES = {
        "block"    => N_(
          "Block Zone"
        ),
        "dmz"      => N_(
          "Demilitarized Zone"
        ),
        "drop"     => N_(
          "Drop Zone"
        ),
        "external" => N_(
          "External Zone"
        ),
        "home"     => N_(
          "Home Zone"
        ),
        "internal" => N_(
          "Internal Zone"
        ),
        "public"   => N_(
          "Public Zone"
        ),
        "trusted"  => N_(
          "Trusted Zone"
        ),
        "work"     => N_(
          "Work Zone"
        )
      }.freeze

      def self.known_zones
        KNOWN_ZONES
      end
    end
  end
end
