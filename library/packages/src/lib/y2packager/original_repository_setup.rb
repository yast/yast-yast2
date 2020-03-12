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

require "singleton"

require "yast"
require "yast/logger"
require "y2packager/repository"
require "y2packager/service"

module Y2Packager
  #
  # This class remembers the current repository setup. This is useful
  # during upgrade when we need to know which repositories/services
  # were already present in the original system and which are the new
  # repositories used for migration.
  #
  # @since 4.2.60
  class OriginalRepositorySetup
    include Yast::Logger
    include Singleton

    attr_reader :repositories, :services

    # constructor, initialize the stored lists to empty lists
    def initialize
      @repositories = []
      @services = []
    end

    # Read and store the current repository/service setup.
    # @param installation_repositories [Array<Y2Packager::Repository>]
    def read(installation_repositories = [])
      # skip the installation repositories, we need to keep them
      aliases = installation_repositories.map(&:repo_alias)
      @repositories = Repository.all.reject { |r| aliases.include?(r.repo_alias) }
      @services = Service.all
      log.info("Found #{repositories.size} repositories and #{services.size} services")
    end

    # Is the service present in the stored list?
    #
    # @param [String] service_alias Alias of the service
    def service?(service_alias)
      services.any? { |s| s.alias == service_alias }
    end

    # Is the repository present in the stored list?
    #
    # @param [String] service_alias Alias of the service
    def repository?(repository_alias)
      repositories.any? { |r| r.alias == repository_alias }
    end
  end
end
