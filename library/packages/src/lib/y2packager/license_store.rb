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

require 'singleton'

module Y2Packager
  class LicenseStore
    include Singleton

    attr_reader :product_licenses

    def initialize
      @product_licenses = {}
    end

    def license_for(product_name)
      @product_licenses[product_name]
    end

    def add_license_for(product_name, license)
      stored_license = license(license.id)

      @product_licenses[product_name] = stored_license || license
    end
  private

    def license(id)
      @product_licenses.values.find { |l| l.id == id }
    end
  end
end
