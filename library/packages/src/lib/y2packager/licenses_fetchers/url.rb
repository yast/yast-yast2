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

require "y2packager/licenses_fetchers/base"

module Y2Packager
  module LicensesFetchers
    # This class reads the licenses from the eula_url product property
    #
    # FIXME: Finish implementation
    class Url < Base
      def license_content(_lang)
        "Fetching product license"
      end

      def license_locales
        [License::DEFAULT_LANG]
      end

      def license_confirmation_required?
        false
      end
    end
  end
end
