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
# File:  modules/Product.ycp
# Package:  yast2
# Summary:  Product data
# Authors:  Klaus Kaempf <kkaempf@suse.de>
#    Lukas Ocilka <locilka@suse.cz>
#
# $Id$
require "yast"
require "y2packager/product_reader"
require "y2packager/resolvable"
require "installation/installation_info"

module Yast
  class ProductClass < Module
    include Yast::Logger

    def main
      Yast.import "Pkg"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "OSRelease"
      Yast.import "PackageLock"
      Yast.import "PackageSystem"
    end

    # Loads and returns base product property
    #
    # @param [Symbol] key (optional)
    def find_property(key = __callee__)
      load_product_data(key)
      get_property(key)
    end

    # Long product name including version
    alias_method :name, :find_property

    # Short product name
    alias_method :short_name, :find_property

    # Product version
    alias_method :version, :find_property

    # Boolean whether product requires to run online update
    alias_method :run_you, :find_property

    # Array of Strings - Product flags such as "no_you"
    alias_method :flags, :find_property

    # URL to release notes
    alias_method :relnotesurl, :find_property

    # Array of URLs of all release notes
    alias_method :relnotesurl_all, :find_property

    # Hash of { URL => product_name } pairs
    alias_method :product_of_relnotes, :find_property

    # Values loaded from os-release file
    OS_RELEASE_PROPERTIES = [
      :name, :short_name, :version
    ].freeze

    # All these methods have been dropped
    DROPPED_METHODS = [
      :vendor, :dist, :distproduct, :distversion, :shortlabel
    ].freeze

    # Returns list Hashes of selected (installation) or installed (running system)
    # base products got from libzypp
    #
    # @return [Array <Hash>] with product definitions
    def FindBaseProducts
      return unless load_zypp

      log.info "Looking for base products"

      products = Y2Packager::Resolvable.find(kind: :product) || []

      # For all (not only base) products
      # FIXME: filling release notes is a nasty side effect of searching the base product,
      # it should be handled separately...
      required_status = use_installed_products? ? :installed : :selected
      fill_up_relnotes(products.select { |p| p.status == required_status })

      # list of products defined by the "system-installation()" provides
      system_products = Y2Packager::ProductReader.installation_package_mapping.keys
      selected = Pkg.IsAnyResolvable(:product, :to_install)

      # Use only base products
      products.select! do |p|
        # The category "base" is not set during installation yet, it is set
        # only for _installed_ base product (otherwise "addon" is reported).
        if use_installed_products?
          p.category == "base"
        elsif system_products && !system_products.empty?
          # the base product is marked by "system-installation()" provides
          status = selected ? :selected : :available
          system_products.include?(p.name) && p.status == status
        else
          # Use the product from the initial repository as a fallback
          p.source == 0
        end
      end

      log.info "Found #{products.size} base product(s): #{products.map(&:name).inspect}"

      if products.empty?
        log.error "No base product found"
        # Logging all information about the product evaluation
        ::Installation::InstallationInfo.instance.write("no_base_product_found")
        raise "No base product found"
      elsif products.size > 1
        log.warn "More than one base product found!"
      end

      # returns a hash in order to not change the interface
      products.map do |p|
        { "name"            => p.name,
          "short_name"      => p.short_name,
          "display_name"    => p.display_name,
          "version"         => p.version,
          "arch"            => p.arch,
          "category"        => p.category,
          "vendor"          => p.vendor,
          "status"          => p.status,
          "relnotes_url"    => p.relnotes_url,
          "register_target" => p.register_target }
      end
    end

    # Reads products from libzypp and fills the internal products cache
    # that can be read by other methods in this library
    def ReadProducts
      # Do not read any product information from zypp on a running system
      return if Mode.config

      Builtins.y2milestone("Product.#{__method__} started")
      return unless load_zypp

      base_product = FindBaseProducts().fetch(0, {})

      set_property(
        :name,
        base_product.fetch("display_name",
          base_product.fetch("summary",
            base_product.fetch("name", "")))
      )

      set_property(:short_name, base_product.fetch("short_name", name))
      set_property(:version, base_product.fetch("version", "").split("-")[0])
      set_property(:relnotesurl, base_product.fetch("relnotes_url", ""))
      set_property(:flags, base_product.fetch("flags", []))
      set_property(:run_you, flags.include?("no_you"))

      nil
    end

  private

    # Is it possible to use os-release file?
    def can_use_os_release_file?
      !Stage.initial && OSRelease.os_release_exists?
    end

    # Whether to use :installed or :selected products
    def use_installed_products?
      # Live installation sets Stage to initial
      Mode.live_installation || !Stage.initial
    end

    # Ensures that we can load data from libzypp
    # @return [Boolean] false if libzypp lock cannot be obtained, otherwise true
    def load_zypp
      if !PackageLock.Check
        Builtins.y2error("Packager is locked, can't read product info!")
        return false
      end

      if use_installed_products?
        PackageSystem.EnsureTargetInit
      else
        PackageSystem.EnsureSourceInit unless Stage.initial
      end

      true
    end

    # Reads basic product information from os-release file
    #
    # @return [Boolean] whether all the data have been successfully loaded
    def read_os_release_file
      set_property(:short_name, OSRelease.ReleaseName)
      set_property(:version, OSRelease.ReleaseVersion)
      set_property(:name, OSRelease.ReleaseInformation)

      OS_RELEASE_PROPERTIES.all? { |key| !get_property(key).nil? && !get_property(key).empty? }
    end

    # Uses products information to fill up release-notes variables
    def fill_up_relnotes(products)
      all_release_notes = []
      release_notes_to_product = {}

      products.map do |p|
        next if p.relnotes_url == ""

        url = p.relnotes_url
        all_release_notes << url
        release_notes_to_product[url] = p.display_name
      end

      set_property(:relnotesurl_all, all_release_notes)
      set_property(:product_of_relnotes, release_notes_to_product)
    end

    # Fills up internal product data
    #
    # @param [Symbol] key
    # @param [Any] value
    def set_property(key, value)
      current_value = get_property(key)

      # Redefining already existent information
      if !current_value.nil? && !current_value.empty? && current_value != value
        if value.nil? || value == ""
          log.error "Ignoring setting new Product property #{key} (#{current_value}) to new value '#{value}'"
          return
        else
          log.warn "Redefining Product property #{key} (#{current_value}) to new value '#{value}'"
        end
      end

      @product[key] = value
    end

    # Returns product property
    #
    # @param [Symbol] key
    def get_property(key)
      @product ||= {}
      @product[key]
    end

    # Loads product information from os-release or libzypp
    def load_product_data(key)
      @product ||= {}

      current_value = get_property(key)
      # Already loaded
      return if !current_value.nil?

      # Try to read the data from os-release (fast)
      if OS_RELEASE_PROPERTIES.include?(key) && can_use_os_release_file?
        return if read_os_release_file

        log.warn "Incomplete os-release file, continue reading from zypp"
      end

      # Read from libzypp (expensive)
      ReadProducts()

      raise "Cannot determine the base product property #{key}" if get_property(key).nil?
    end

    # Needed for testing and internal cleanup
    # Resets internal cache
    def reset
      @product = nil
    end

    # Handles using dropped methods
    def method_missing(method_name, *args, &block)
      if DROPPED_METHODS.include? method_name
        log.error "Method Product.#{method_name} dropped"
        raise "Method Product.#{method_name} has been dropped"
      else
        super
      end
    end

    def respond_to_missing?(name, _include_private)
      DROPPED_METHODS.include?(name)
    end

    publish function: :name, type: "string ()"
    publish function: :short_name, type: "string ()"
    publish function: :version, type: "string ()"
    publish function: :vendor, type: "string ()"
    publish function: :relnotesurl, type: "string ()"
    publish function: :relnotesurl_all, type: "list <string> ()"
    publish function: :product_of_relnotes, type: "map <string, string> ()"
    publish function: :run_you, type: "boolean ()"
    publish function: :flags, type: "list ()"

    publish function: :FindBaseProducts, type: "list <map <string, any>> ()"
    publish function: :ReadProducts, type: "void ()"
  end

  Product = ProductClass.new
  Product.main
end
