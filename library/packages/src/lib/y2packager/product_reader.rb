# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "yast"
require "y2packager/product"
require "y2packager/product_sorter"

Yast.import "Pkg"

module Y2Packager
  # Read the product information from libzypp
  class ProductReader
    include Yast::Logger

    class << self
      # Installation packages map
      #
      # This map contains the correspondence between products and the
      # installation package for each product.
      #
      # The information is read only once and cached for further queries.
      #
      # @return [Hash<String,String>] product name -> installation package name
      def installation_package_mapping
        return @installation_package_mapping if @installation_package_mapping
        installation_packages = Yast::Pkg.PkgQueryProvides("system-installation()")
        log.info "Installation packages: #{installation_packages.inspect}"

        @installation_package_mapping = {}
        installation_packages.each do |list|
          pkg_name = list.first
          # There can be more instances of same package in different version. We except that one
          # package provide same product installation. So we just pick the first one.
          dependencies = Yast::Pkg.ResolvableDependencies(pkg_name, :package, "").first["deps"]
          install_provide = dependencies.find do |d|
            d["provides"] && d["provides"].match(/system-installation\(\)/)
          end

          # parse product name from provides. Format of provide is
          # `system-installation() = <product_name>`
          product_name = install_provide["provides"][/system-installation\(\)\s*=\s*(\S+)/, 1]
          log.info "package #{pkg_name} install product #{product_name}"
          @installation_package_mapping[product_name] = pkg_name
        end

        @installation_package_mapping
      end
    end

    # Available products
    #
    # @return [Array<Product>] Available products
    def all_products
      @all_products ||= available_products.map do |prod|
        prod_pkg = product_package(prod["product_package"], prod["source"])

        if prod_pkg
          prod_pkg["deps"].find { |dep| dep["provides"] =~ /\Adisplayorder\(\s*([0-9]+)\s*\)\z/ }
          displayorder = Regexp.last_match[1].to_i if Regexp.last_match
        end

        Y2Packager::Product.new(
          name: prod["name"], short_name: prod["short_name"], display_name: prod["display_name"],
          version: prod["version"], arch: prod["arch"], category: prod["category"],
          vendor: prod["vendor"], order: displayorder,
          installation_package: installation_package_mapping[prod["name"]]
        )
      end
    end

    # In installation Read the available libzypp base products for installation
    # @return [Array<Y2Packager::Product>] the found available base products,
    #   the products are sorted by the 'displayorder' provides value
    def available_base_products
      # If no product contains a 'system-installation()' tag but there is only 1 product,
      # we assume that it is the base one.
      if all_products.size == 1 && installation_package_mapping.empty?
        log.info "Assuming that #{all_products.inspect} is the base product."
        return all_products
      end

      # only installable products
      products = all_products.select(&:installation_package).sort(&::Y2Packager::PRODUCT_SORTER)
      log.info "available base products #{products}"
      products
    end

    def product_package(name, repo_id)
      return nil unless name
      Yast::Pkg.ResolvableDependencies(name, :package, "").find do |prod|
        prod["source"] == repo_id
      end
    end

  private

    # read the available products, remove potential duplicates
    # @return [Array<Hash>] pkg-bindings data structure
    def available_products
      products = Yast::Pkg.ResolvableProperties("", :product, "")

      # remove e.g. installed products
      products.select! { |p| p["status"] == :available || p["status"] == :selected }

      # remove duplicates, there migth be different flavors ("DVD"/"POOL")
      # or archs (x86_64/i586), when selecting the product to install later
      # libzypp will select the correct arch automatically
      products.uniq! { |p| "#{p["name"]}__#{p["version"]}" }
      log.info "Found products: #{products.map { |p| p["name"] }}"

      products
    end

    def installation_package_mapping
      self.class.installation_package_mapping
    end
  end
end
