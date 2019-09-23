# ------------------------------------------------------------------------------
# Copyright (c) 2019 SUSE LLC
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
require "y2packager/product_license_mixin"

Yast.import "Arch"
Yast.import "Linuxrc"
Yast.import "ProductFeatures"

module Y2Packager
  # This class implements a base product read from the control.xml file.
  class ProductControlProduct
    extend Yast::Logger
    include ProductLicenseMixin

    attr_reader :name, :version, :arch, :label, :license_url, :register_target

    # map the Arch.architecture to the arch expected by SCC
    REG_ARCH = {
      "s390_32" => "s390",
      "s390_64" => "s390x",
      # ppc64le is the only supported PPC arch, we do not have to distinguish the BE/LE variants
      "ppc64"   => "ppc64le"
    }.freeze

    class << self
      attr_accessor :selected

      #
      # Read the base products from the control.xml file. The products for the incompatible
      # machine architecture and the hidden products are filtered out.
      #
      # @return [Array<Installation::ProductControlProduct>] List of the products
      def products
        return @products if @products

        control_products = Yast::ProductFeatures.GetFeature("software", "base_products")
        arch = REG_ARCH[Yast::Arch.architecture] || Yast::Arch.architecture
        linuxrc_products = (Yast::Linuxrc.InstallInf("specialproduct") || "").split(",").map(&:strip)

        @products = control_products.each_with_object([]) do |p, array|
          # a hidden product requested?
          if p["special_product"] && !linuxrc_products.include?(p["name"])
            log.info "Skipping special hidden product #{p["name"]}"
            next
          end

          # compatible arch?
          if p["archs"] && !p["archs"].split(",").map(&:strip).include?(arch)
            log.info "Skipping product #{p["name"]} - not compatible with arch #{arch}"
            next
          end

          array << new(
            name:            p["name"],
            version:         p["version"],
            arch:            arch,
            label:           p["display_name"],
            license_url:     p["license_url"],
            # expand the "$arch" placeholder
            register_target: (p["register_target"] || "").gsub("$arch", arch)
          )
        end
      end
    end

    # Constructor
    # @param name [String] product name (the identifier, e.g. "SLES")
    # @param version [String] version ("15.2")
    # @param arch [String] The architecture ("x86_64")
    # @param label [String] The user visible name ("SUSE Linux Enterprise Server 15 SP2")
    # @param license_url [String] License URL
    # @param register_target [String] The registration target name used
    #   for registering the product, the $arch variable is replaced
    #   by the current machine architecture
    def initialize(name:, version:, arch:, label:, license_url:, register_target:)
      @name = name
      @version = version
      @arch = arch
      @label = label
      @license_url = license_url
      @register_target = register_target
    end

    # Is the product selected?
    # @return [Boolean] true if the product is the selected base product
    def selected?
      self == self.class.selected
    end
  end
end
