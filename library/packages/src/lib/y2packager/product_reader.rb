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
require "y2packager/resolvable"

Yast.import "Pkg"
Yast.import "Linuxrc"
Yast.import "Stage"

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
      # The information is always read again. Reason is that that url can be invalid,
      # but user fix it later. This way it cache invalid result. See bsc#1086840
      # ProductReader instance cache it properly, but caching for installation life-time
      # should be prevented.
      #
      # @return [Hash<String,String>] product name -> installation package name
      def installation_package_mapping
        installation_packages = Yast::Pkg.PkgQueryProvides("system-installation()")
        log.info "Installation packages: #{installation_packages.inspect}"

        installation_package_mapping = {}
        installation_packages.each do |list|
          pkg_name = list.first
          # There can be more instances of same package in different version.
          # Prefer the selected or the available package, they should provide newer data
          # than the installed one.
          packages = Yast::Pkg.Resolvables({ name: pkg_name, kind: :package }, [:dependencies, :status])
          package = packages.find { |p| p["status"] == :selected } ||
            packages.find { |p| p["status"] == :available } ||
            packages.first

          dependencies = package["deps"]
          install_provides = dependencies.find_all do |d|
            d["provides"]&.match(/system-installation\(\)/)
          end

          # parse product name from provides. Format of provide is
          # `system-installation() = <product_name>`
          install_provides.each do |install_provide|
            product_name = install_provide["provides"][/system-installation\(\)\s*=\s*(\S+)/, 1]
            log.info "package #{pkg_name} install product #{product_name}"
            installation_package_mapping[product_name] = pkg_name
          end

        end

        installation_package_mapping
      end
    end

    # Available products
    #
    # @return [Array<Product>] Available products
    def all_products(force_repos: false)
      linuxrc_special_products = if Yast::Linuxrc.InstallInf("specialproduct")
        linuxrc_string(Yast::Linuxrc.InstallInf("specialproduct")).split(",")
      else
        []
      end

      return @all_products if @all_products && !force_repos

      if Yast::Stage.initial && Y2Packager::MediumType.online? && !force_repos
        return Y2Packager::ProductControlProduct.products.each_with_object([]) do |p, result|
          result << Y2Packager::Product.new(name: p.name, display_name: p.label,
              version: p.version, arch: p.arch,
              short_name: p.name, # TODO: verify that name and shortname are same for control products
              installation_package: "Test") # just hack as we do not know current package name yet
        end
      end

      @all_products = []

      available_products.each do |prod|
        prod_pkg = product_package(prod.product_package)

        if prod_pkg
          # remove special products if they have not been defined in linuxrc
          prod_pkg.deps.find { |dep| dep["provides"] =~ /\Aspecialproduct\(\s*(.*?)\s*\)\z/ }
          special_product_tag = linuxrc_string(Regexp.last_match[1]) if Regexp.last_match
          if special_product_tag && !linuxrc_special_products.include?(special_product_tag)
            log.info "Special product #{prod.name} has not been defined via linuxrc. --> do not offer it"
            next
          end

          # Evaluating display order
          prod_pkg.deps.find { |dep| dep["provides"] =~ /\Adisplayorder\(\s*([0-9]+)\s*\)\z/ }
          displayorder = Regexp.last_match[1].to_i if Regexp.last_match
        end

        @all_products << Y2Packager::Product.new(
          name: prod.name, short_name: prod.short_name, display_name: prod.display_name,
          version: prod.version, arch: prod.arch, category: prod.category,
          vendor: prod.vendor, order: displayorder,
          installation_package: installation_package_mapping[prod.name]
        )
      end

      @all_products
    end

    # In installation Read the available libzypp base products for installation
    # @return [Array<Y2Packager::Product>] the found available base products,
    #   the products are sorted by the 'displayorder' provides value
    def available_base_products(force_repos: false)
      # If no product contains a 'system-installation()' tag but there is only 1 product,
      # we assume that it is the base one.
      products = all_products(force_repos: force_repos)
      if products.size == 1 && installation_package_mapping.empty?
        log.info "Assuming that #{products.inspect} is the base product."
        return products
      end

      log.info "all products #{products}"
      # only installable products
      products = products.select(&:installation_package).sort(&::Y2Packager::PRODUCT_SORTER)
      log.info "available base products #{products}"
      products
    end

    # Read the installed base product
    # @return [Y2Packager::Product,nil] the installed base product or nil if not found
    def installed_base_product
      base = base_product
      return nil unless base

      Y2Packager::Product.new(
        name: base.name, short_name: base.short_name, display_name: base.display_name,
        version: base.version, arch: base.arch, category: base.category,
        vendor: base.vendor, installation_package: installation_package_mapping[base.name]
      )
    end

    # All installed products
    # @return [Array<Y2Packager::Product>] the product list
    def all_installed_products
      installed_products.map do |p|
        Y2Packager::Product.new(
          name: p.name, short_name: p.short_name, display_name: p.display_name,
          version: p.version, arch: p.arch, category: p.category,
          vendor: p.vendor, installation_package: installation_package_mapping[p.name]
        )
      end
    end

    def product_package(name, _repo_id = nil)
      return nil unless name

      # find the highest version
      Y2Packager::Resolvable.find(kind: :package, name: name).reduce(nil) do |a, p|
        (!a || (Yast::Pkg.CompareVersions(a.version, p.version) < 0)) ? p : a
      end
    end

  private

    # read the available products, remove potential duplicates
    # @return [Array<Hash>] pkg-bindings data structure
    def zypp_products
      products = Y2Packager::Resolvable.find(kind: :product)

      # remove duplicates, there might be different flavors ("DVD"/"POOL")
      # or archs (x86_64/i586), when selecting the product to install later
      # libzypp will select the correct arch automatically,
      # keep products with different location, they are filtered out later
      products.uniq! { |p| "#{p.name}__#{p.version}__#{resolvable_location(p)}" }
      log.info "Found products: #{products.map(&:name)}"

      products
    end

    # read the available products, remove potential duplicates
    # @return [Array<Hash>] pkg-bindings data structures
    def available_products
      # select only the available or to be installed products
      zypp_products.select { |p| p.status == :available || p.status == :selected }
    end

    # read the installed products
    # @return [Array<Hash>] pkg-bindings data structures
    def installed_products
      # select only the installed or to be removed products
      zypp_products.select { |p| p.status == :installed || p.status == :removed }
    end

    # find the installed base product
    # @return[Hash,nil] the pkg-bindings product structure or nil if not found
    def base_product
      # The base product is identified by the /etc/products.d/baseproduct symlink
      # and because a symlink can point only to one file there can be only one base product.
      # The "installed" condition is actually not required because that symlink is created
      # only for installed products. (Just make sure it still works in case the libzypp
      # internal implementation is changed.)
      base = installed_products.find { |p| p.type == "base" }

      log.info("Found installed base product: #{base}")
      base
    end

    def installation_package_mapping
      @installation_package_mapping ||= self.class.installation_package_mapping
    end

    # Process the string in a linuxrc way: remove the "-", "_", "." characters,
    # convert it to downcase for case insensitive comparison.
    #
    # @param input [String] the input string
    #
    # @return [String] the processed string
    #
    def linuxrc_string(input)
      return nil if input.nil?

      ret = input.gsub(/[-_.]/, "")
      ret.downcase
    end

    #
    # Evaluate the resolvable location (on system or on media).
    #
    # @param res [Hash] the resolvable hash obtained from pkg-bindings
    #
    # @return [Symbol] `:on_medium` or `:on_system`
    #
    def resolvable_location(res)
      case res.status
      when :available, :selected
        :on_medium
      when :installed, :removed
        :on_system
      else
        # just in case pkg-bindings add some new status...
        raise "Unexpected resolvable status: #{res.status}"
      end
    end
  end
end
