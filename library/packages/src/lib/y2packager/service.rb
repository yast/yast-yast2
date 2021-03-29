# typed: true
# ------------------------------------------------------------------------------
# Copyright (c) 2020 SUSE LINUX GmbH, Nuremberg, Germany.
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
require "yast/logger"

Yast.import "Pkg"

module Y2Packager
  #
  # This class represents a libzypp service.
  #
  # @since 4.2.60
  class Service
    include Yast::Logger

    attr_reader :alias, :url, :enabled, :auto_refresh, :file, :type,
      :repos_to_enable, :repos_to_disable, :name

    def initialize(service_alias:, auto_refresh: nil, enabled: nil, file: nil, name: "",
      repos_to_disable: [], repos_to_enable: [], type: nil, url: nil)

      @alias = service_alias
      @auto_refresh = auto_refresh
      @enabled = enabled
      @file = file
      @name = name
      @repos_to_disable = repos_to_disable
      @repos_to_enable = repos_to_enable
      @type = type
      @url = url
    end

    def self.all
      aliases = Yast::Pkg.ServiceAliases
      services = aliases.map do |a|
        srv = Yast::Pkg.ServiceGet(a)
        new(
          service_alias:    a,
          auto_refresh:     srv["autorefresh"],
          enabled:          srv["enabled"],
          file:             srv["file"],
          name:             srv["name"],
          repos_to_disable: srv["repos_to_disable"] || [],
          repos_to_enable:  srv["repos_to_enable"] || [],
          type:             srv["type"],
          url:              srv["url"]
        )
      end

      log.info("Found #{services.size} services (#{services.map(&:alias).inspect})")

      services
    end
  end
end
