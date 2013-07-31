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
    def main
      Yast.import "Pkg"

      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "SuSERelease"
      Yast.import "PackageLock"
      Yast.import "PackageSystem"

      # General product name and version
      @name = "" # "SuSE Linux 8.1"
      @short_name = "" # "SuSE Linux"
      @version = "" # "8.1"
      @vendor = "" # "SuSE Linux AG"

      # Distribution: Personal, Professional, etc.
      @dist = ""
      @distproduct = "" # "SuSE-Linux-Professional-INT-i386"
      @distversion = "" # "8.1-0"

      # base product
      @baseproduct = "" # "UnitedLinux"
      @baseversion = "" # "1.0"

      # url of release notes (downloaded during internet test)
      @relnotesurl = ""

      # list of all urls of release notes (downloaded during internet test)
      # bugzilla #160563
      @relnotesurl_all = []

      # map relnotes url to product name
      @product_of_relnotes = {}

      #  Run YOU during the Internet connection test.
      @run_you = true

      # list of flags from content file
      @flags = []

      # list of patterns from content file
      @patterns = []

      # Short label for bootloader entry
      @shortlabel = ""
      Product()
    end

    def FindBaseProducts
      # bugzilla #238556
      if !PackageLock.Check
        Builtins.y2error("Locked!")
        return []
      end

      Builtins.y2milestone("Looking for base products")
      products = Pkg.ResolvableProperties("", :product, "")
      products = Builtins.filter(products) do |p|
        Ops.get_symbol(p, "status", :none) == :installed
      end

      Builtins.y2milestone("All found products: %1", products)

      products = Builtins.filter(products) do |p|
        # bug 165314, relnotes_url needn't be defined (or empty string)
        if Ops.get_string(p, "relnotes_url", "") != ""
          rn_url = Ops.get_string(p, "relnotes_url", "")
          @relnotesurl_all = Builtins.add(@relnotesurl_all, rn_url)
          # bug 180581, relnotes should be identified by name
          Ops.set(
            @product_of_relnotes,
            rn_url,
            Ops.get_string(p, "display_name", "")
          )
        end
        Ops.get_string(p, "category", "") == "base"
      end

      Builtins.y2milestone("Found base products: %1", products)
      if Builtins.size(products) == 0
        Builtins.y2error("No base product found")
      elsif Ops.greater_than(Builtins.size(products), 1)
        Builtins.y2warning("More than one base product found")
      end
      deep_copy(products)
    end

    # Read the products from the package manager
    def ReadProducts
      Builtins.y2milestone("Product::ReadProducts() started")
      if !Mode.config
        # bugzilla #238556
        if !PackageLock.Check
          Builtins.y2error("Locked!")
          return
        end

        PackageSystem.EnsureTargetInit
        PackageSystem.EnsureSourceInit # TODO: is it still needed?

        # run the solver to compute the installed products
        Pkg.PkgSolve(true) # TODO: is it still needed?

        base_products = FindBaseProducts()
        base_product = Ops.get(base_products, 0, {}) # there should be only one - hopefuly

        @name = Ops.get_string(
          base_product,
          "display_name",
          Ops.get_string(
            base_product,
            "summary",
            Ops.get_string(base_product, "name", "")
          )
        )
        @short_name = Ops.get_string(base_product, "short_name", @name)
        @version = Ops.get_string(base_product, "version", "")
        @vendor = Ops.get_string(base_product, "vendor", "")
        @relnotesurl = Ops.get_string(base_product, "relnotes_url", "")
        @flags = Ops.get_list(base_product, "flags", [])
      end

      nil
    end


    # -----------------------------------------------
    # Constructor
    def Product
      if Stage.initial && !Mode.live_installation
        # it should use the same mechanism as running system. But it would
        # mean to initialize package manager from constructor, which is
        # not reasonable
        @name = Convert.to_string(SCR.Read(path(".content.LABEL")))
        @short_name = Convert.to_string(SCR.Read(path(".content.SHORTLABEL")))
        @short_name = @name if @short_name == nil
        @version = Convert.to_string(SCR.Read(path(".content.VERSION")))
        @vendor = Convert.to_string(SCR.Read(path(".content.VENDOR")))

        @distproduct = Convert.to_string(SCR.Read(path(".content.DISTPRODUCT")))
        @distversion = Convert.to_string(SCR.Read(path(".content.DISTVERSION")))

        @baseproduct = Convert.to_string(SCR.Read(path(".content.BASEPRODUCT")))
        @baseproduct = @name if @baseproduct == ""
        @baseversion = Convert.to_string(SCR.Read(path(".content.BASEVERSION")))

        @relnotesurl = Convert.to_string(SCR.Read(path(".content.RELNOTESURL")))
        @shortlabel = Convert.to_string(SCR.Read(path(".content.SHORTLABEL")))

        tmp1 = SCR.Read(path(".content.FLAGS"))
        if tmp1 != nil
          @flags = Builtins.splitstring(Convert.to_string(tmp1), " ")
        end
        tmp1 = SCR.Read(path(".content.PATTERNS"))
        if tmp1 != nil
          @patterns = Builtins.splitstring(Convert.to_string(tmp1), " ")
        end

        # bugzilla #252122, since openSUSE 10.3
        # deprecated:
        # 		content.PATTERNS: abc cba bac
        # should re replaced with (and/or)
        # 		content.REQUIRES: pattern:abc pattern:cba pattern:bac
        #		content.RECOMMENDS: pattern:abc pattern:cba pattern:bac
        if @patterns != []
          Builtins.y2warning(
            "Product content file contains deprecated PATTERNS tag, use REQUIRES and/or RECOMMENDS instead"
          )
          Builtins.y2milestone("PATTERNS: %1", @patterns)
        end
      elsif !Mode.config
        @short_name = SuSERelease.ReleaseName
        @version = SuSERelease.ReleaseVersion
        @name = Ops.add(Ops.add(@short_name, " "), @version)
      end

      @distproduct = "" if @distproduct == nil
      @dist = Ops.get(Builtins.splitstring(@distproduct, "-"), 2, "")

      @run_you = !Builtins.contains(@flags, "no_you")

      # set the product name for UI
      Yast.import "Wizard"

      Builtins.y2milestone("Product name: '%1'", @name)

      Wizard.SetProductName(@name) if @name != nil && @name != ""

      nil
    end

    publish :variable => :name, :type => "string"
    publish :variable => :short_name, :type => "string"
    publish :variable => :version, :type => "string"
    publish :variable => :vendor, :type => "string"
    publish :variable => :dist, :type => "string"
    publish :variable => :distproduct, :type => "string"
    publish :variable => :distversion, :type => "string"
    publish :variable => :baseproduct, :type => "string"
    publish :variable => :baseversion, :type => "string"
    publish :variable => :relnotesurl, :type => "string"
    publish :variable => :relnotesurl_all, :type => "list <string>"
    publish :variable => :product_of_relnotes, :type => "map <string, string>"
    publish :variable => :run_you, :type => "boolean"
    publish :variable => :flags, :type => "list"
    publish :variable => :patterns, :type => "list <string>"
    publish :variable => :shortlabel, :type => "string"
    publish :function => :FindBaseProducts, :type => "list <map <string, any>> ()"
    publish :function => :ReadProducts, :type => "void ()"
    publish :function => :Product, :type => "void ()"
  end

  Product = ProductClass.new
  Product.main
end
