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
require "y2packager/backend"
require "y2packager/rpm_repo"
require "y2packager/package"
require "y2packager/product"

module Y2Packager
  # Backend implementation for libzypp
  class LibzyppBackend < Backend
    # Initialize the libzypp subsystem using the pkg-bindings
    def probe
      Yast.import "Pkg"
      Yast.import "PackageLock"
      Yast::Pkg.TargetInitialize("/")
      Yast::Pkg.TargetLoad
      Yast::Pkg.SourceRestore
      Yast::Pkg.SourceLoad
    end

    # Reads the repositories from the system
    #
    # @return [Array<RpmRepo>]
    def repositories
      Yast::Pkg.SourceGetCurrent(false).map do |repo_id|
        repo = Yast::Pkg.SourceGeneralData(repo_id)
        raise NotFound if repo.nil?

        RpmRepo.new(repo_id: repo_id, repo_alias: repo["alias"],
          enabled: repo["enabled"], name: repo["name"],
          autorefresh: repo["autorefresh"], url: repo["raw_url"],
          product_dir: repo["product_dir"])
      end
    end

    # @todo Allow passing multiple statuses
    # @todo Use a set of default properties so you do not need to explictly pass them
    def search(conditions:, properties:)
      resolvables = Yast::Pkg.Resolvables(
        conditions,
        (properties + [:kind]).uniq
      )

      resolvables.map do |res|
        meth = "hash_to_#{res["kind"]}"
        next res unless respond_to?(meth, true)

        send(meth, res)
      end
    end

  private

    def hash_to_product(hsh)
      Y2Packager::Product.new(
        name: hsh["name"], arch: hsh["arch"], version: hsh["version"]
      )
    end

    def hash_to_package(hsh)
      Y2Packager::Package.new(
        hsh["name"], hsh["source"], hsh["version"]
      )
    end
  end
end
