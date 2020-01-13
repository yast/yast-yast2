# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------
#

# A factory which creates random libzypp products for testing.
class ProductFactory
  # Create a product, the default random attributes can be customized via arguments.
  # @return [Hash] product hash as returned by the Pkg.ResolvableProperties
  #   and Pkg.ResolvableDependencies functions
  def self.create_product(attrs = {})
    product = {}

    # generate 12 random characters from a-z
    charset = ("a".."z").to_a
    name = (1..12).map { charset[rand(charset.size)] }.join

    # construct a "human readable" product name
    product_name = name.capitalize
    # construct the internal product ID
    product_id = name[0..4]
    # service pack level
    sp = rand(1..4)

    product["kind"] = :product
    product["arch"] = attrs["arch"] || "x86_64"
    product["category"] = attrs["category"] || "addon"
    product["description"] = attrs["description"] || "SUSE Linux Enterprise #{product_name}."
    product["display_name"] = attrs["display_name"] || "SUSE Linux Enterprise #{product_name}"
    product["download_size"] = attrs["download_size"] || 0
    # default: 2024-10-31
    product["eol"] = attrs["eol"] || 1730332800
    product["flags"] = attrs["flags"] || []
    product["flavor"] = attrs["flavor"] || "POOL"
    product["inst_size"] = attrs["inst_size"] || 0
    product["locked"] = attrs.fetch("locked", false)
    product["medium_nr"] = attrs["medium_nr"] || 0
    product["name"] = attrs["name"] || "sle-#{product_id}"
    product["on_system_by_user"] = attrs.fetch("on_system_by_user", false)
    product["product_file"] = attrs["product_file"] || "sle-#{product_id}.prod"
    product["product_line"] = attrs["product_line"] || ""
    product["product_package"] = attrs.fetch("product_package", "sle-#{product_id}-release")
    product["register_release"] = attrs["register_release"] || ""
    product["register_target"] = attrs["register_target"] || "sle-12-x86_64"
    product["relnotes_url"] = attrs["relnotes_url"] ||
      "https://www.suse.com/releasenotes/#{product["arch"]}/SLE-#{product_id}/12-SP#{sp}/" \
        "release-notes-#{product_id}.rpm"
    product["relnotes_urls"] = attrs["relnotes_urls"] || [product["relnotes_url"]]
    product["short_name"] = attrs["short_name"] || "SLE#{product_id.upcase}12-SP#{sp}"
    product["source"] = attrs["source"] || rand(10)
    product["status"] = attrs["status"] || :available
    product["summary"] = attrs["summary"] || "SUSE Linux Enterprise #{product_name}"
    product["transact_by"] = attrs["transact_by"] || :solver
    product["type"] = attrs["type"] || "addon"
    product["update_urls"] = attrs["update_urls"] || []
    product["vendor"] = attrs["vendor"] || "SUSE LLC <https://www.suse.com/>"
    product["version"] = attrs["version"] || "12.#{sp}-0"
    product["version_epoch"] = attrs["version_epoch"] || nil
    product["version_release"] = attrs["version_release"] || "0"
    product["version_version"] = attrs["version_version"] || "12.#{sp}"

    # add optional dependencies (returned only by ResolvableDependencies)
    product["deps"] = attrs["deps"] if attrs.key?("deps")

    product
  end

  # create product packages for testing
  # @param [String] product_name name of the product_line
  # @param [Fixnum,nil] src repository ID providing the product
  # @return [Array] created product data: the default pattern name,
  #   the release package name, the release package status,
  #   the product status
  def self.create_product_packages(product_name: "product", src: nil)
    pattern_name = "#{product_name}_pattern"
    package_name = "#{product_name}-release"
    package = Y2Packager::Resolvable.new(
      "kind" => :package,
       "name" => package_name, "status" => :selected,
       "deps" => [{ "requires" => "foo" }, { "provides" => "bar" },
                  { "provides" => "defaultpattern(#{pattern_name})" }]
    )
    product = Y2Packager::Resolvable.new(
      ProductFactory.create_product("status" => :selected,
      "source" => src, "product_package" => package_name)
    )

    [pattern_name, package_name, package, product]
  end
end
