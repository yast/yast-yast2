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
# File:	modules/Product.ycp
# Package:	yast2
# Summary:	Product data
# Authors:	Klaus Kaempf <kkaempf@suse.de>
#		Lukas Ocilka <locilka@suse.cz>
#
# $Id$
require "yast"

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
      @product[key]
    end

    # Long product name incuding version
    alias_method :name, :find_property

    # Short product name
    alias_method :short_name, :find_property

    # Product version
    alias_method :version, :find_property

    # Returns whether product requires to run online update
    alias_method :run_you, :find_property

    # Product flags such as "no_you"
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
    ]

    # All these methods have been dropped
    DROPPED_METHODS = [
      :vendor, :dist, :distproduct, :distversion, :shortlabel
    ]

    # Returns list of selected (installation) or installed (running system)
    # base products got from libzypp
    #
    # @return [Hash] products
    def FindBaseProducts
      return unless load_zypp

      log.info "Looking for base products"

      products = Pkg.ResolvableProperties("", :product, "").dup || []
      required_status = use_installed_products? ? :installed : :selected
      products.select!{ |p| p["status"] == required_status }

      log.info "All #{required_status} products: #{products}"

      # For all (not only base) products
      fill_up_relnotes(products)

      # Use only base products
      products.select! do |p|
        use_installed_products? ? (p["category"] == "base") : (p["source"] == 0)
      end

      log.info "Found #{products.size} base product(s)"

      if products.empty?
        log.error "No base product found"
        raise "No #{required_status} base product found"
      elsif products.size > 1
        log.warn "More than one base product found!"
      end

      deep_copy(products)
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
            base_product.fetch("name", "")
          )
        )
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
      !Stage.initial && !Mode.installation && OSRelease.os_release_exists?
    end

    # Whether to use :installed or :selected products
    def use_installed_products?
      !Mode.installation || Mode.live_installation
    end

    # Ensures that we can load data from libzypp
    def load_zypp
      if !PackageLock.Check
        Builtins.y2error("Packager is locked, can't read product info!")
        return false
      end

      if use_installed_products?
        PackageSystem.EnsureTargetInit
      else
        PackageSystem.EnsureSourceInit
      end

      Pkg.PkgSolve(true)
    end

    # Reads basic product information from os-release file
    def read_os_release_file
      set_property(:short_name, OSRelease.ReleaseName)
      set_property(:version, OSRelease.ReleaseVersion)
      set_property(:name, OSRelease.ReleaseInformation)
    end

    # Uses products information to fill up release-notes variables
    def fill_up_relnotes(products)
      all_release_notes = []
      release_notes_to_product = {}

      products.map do |p|
        if p["relnotes_url"] != ""
          url = p["relnotes_url"]
          all_release_notes << url
          release_notes_to_product[url] = (p["display_name"] || "")
        end
      end

      set_property(:relnotesurl_all, all_release_notes)
      set_property(:product_of_relnotes, release_notes_to_product)
    end

    # Fills up internal product data
    def set_property(key, value)
      # Redefining already existent information
      if @product[key] && !@product[key].empty? && @product[key] != value
        if value.nil? || value == ""
          log.error "Ignoring setting new Product property #{key} (#{@product[key]}) to new value '#{value}'"
          return
        else
          log.warn "Redefining Product property #{key} (#{@product[key]}) to new value '#{value}'"
        end
      end

      @product[key] = value
    end

    # Loads product information from os-release or libzypp
    def load_product_data(key)
      @product ||= {}

      # Already loaded
      return if @product[key]

      # Try to read the data from os-release
      if OS_RELEASE_PROPERTIES.include?(key) && can_use_os_release_file?
        read_os_release_file
        return if OS_RELEASE_PROPERTIES.all?{ |key| @product[key] and !@product[key].empty? }
        log.warn "Incomplete os-release file, continue reading from zypp"
      end

      # Read from libzypp (expensive)
      ReadProducts()

      raise "Cannot determine the base product property #{key}" if @product[key].nil?
    end

    # Needed for testing and internal cleanup
    def reset
      @product = nil
    end

    # Handles using dropped methods
    def method_missing(method_name, *args, &block)
      if DROPPED_METHODS.include? method_name
        log.error "Method #{self.class.name}.#{method_name} dropped"
        raise "Method #{self.class.name}.#{method_name} has been dropped"
      else
        super
      end
    end

    publish :function => :name, :type => "string ()"
    publish :function => :short_name, :type => "string ()"
    publish :function => :version, :type => "string ()"
    publish :function => :vendor, :type => "string ()"
    publish :function => :relnotesurl, :type => "string ()"
    publish :function => :relnotesurl_all, :type => "list <string> ()"
    publish :function => :product_of_relnotes, :type => "map <string, string> ()"
    publish :function => :run_you, :type => "boolean ()"
    publish :function => :flags, :type => "list ()"

    publish :function => :FindBaseProducts, :type => "list <map <string, any>> ()"
    publish :function => :ReadProducts, :type => "void ()"
  end

  Product = ProductClass.new
  Product.main
end
