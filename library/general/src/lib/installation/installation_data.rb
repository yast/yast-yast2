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

require "installation/installation_info"
require "y2packager/medium_type"
require "y2packager/product_reader"
require "y2packager/resolvable"

Yast.import "Mode"
Yast.import "Pkg"

module Installation
  #
  # Class for dumping the general installation data.
  class InstallationData
    # Register the callback for dumping the general installation data
    def self.add
      # already registered
      return if ::Installation::InstallationInfo.instance.added?("installation")

      ::Installation::InstallationInfo.instance.add("installation") do
        data = {
          "mode"                    => Yast::Mode.mode,
          # Do not call Y2Packager::MediumType.type here, it could potentially trigger
          # media detection and downloading repository metadata if the value is not
          # cached yet. Fetch the internal cache value directly, not nice but safe...
          "medium_type"             => Y2Packager::MediumType.instance_variable_get("@type"),
          "repositories"            => Yast::Pkg.SourceGetCurrent(false).map do |repo|
            Yast::Pkg.SourceGeneralData(repo)
          end,
          "services"                => Yast::Pkg.ServiceAliases.map do |s|
            Yast::Pkg.ServiceGet(s)
          end,
          "available_base_products" => Y2Packager::ProductReader.new.available_base_products.map do |product|
            {
              "name"         => product.name,
              "version"      => product.version,
              "display_name" => product.display_name,
              "vendor"       => product.vendor
            }
          end,
          "products"                => Y2Packager::Resolvable.find(kind: :product).map do |product|
            {
              "name"         => product.name,
              "version"      => product.version,
              "display_name" => product.display_name,
              "status"       => product.status,
              "vendor"       => product.vendor,
              "repository"   => product.source,
              "path"         => product.path
            }
          end
        }

        # evaluating root partitions in upgrade
        if Yast::Mode.update
          Yast.import "RootPart"
          data["root_partitions"] = Yast::RootPart.rootPartitions
          data["selected_root_partition"] = Yast::RootPart.selectedRootPartition
        end

        data
      end
    end
  end
end
