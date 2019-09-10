# ------------------------------------------------------------------------------
# Copyright (c) 2018 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "y2packager/licenses_handlers/base"

Yast.import "Pkg"
Yast.import "InstURL"

module Y2Packager
  module LicensesHandlers
    # This class is responsible for interacting with an rpm in order to get/set
    # the license acceptance status for a given product
    class Tarball < Base
      # Set the license confirmation for the product
      #
      # @param confirmed [Boolean] true if it should be accepted; false otherwise
      def confirmation=(confirmed)
        if confirmed
          log.info("License was accepted")
        else
          log.info("License was not accepted")
        end
      end
    end
  end
end
