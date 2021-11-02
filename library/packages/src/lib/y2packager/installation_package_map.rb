# Copyright (c) [2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
Yast.import "Pkg"

module Y2Packager
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
  class InstallationPackageMap
    include Yast::Logger

    def initialize
      @packages_map = nil
    end

    def for(pkg_name)
      packages_map[pkg_name]
    end

  private

    def packages_map
      return @packages_map if @packages_map

      install_pkgs = Yast::Pkg.PkgQueryProvides("system-installation()")
      log.info "Installation packages: #{install_pkgs.inspect}"

      @packages_map = {}

      install_pkgs.each do |list|
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
          @packages_map[product_name] = pkg_name
        end
      end

      @packages_map
    end
  end
end
