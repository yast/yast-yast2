# ------------------------------------------------------------------------------
# Copyright (c) 2022 SUSE LINUX GmbH, Nuremberg, Germany.
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

require "singleton"

module Y2Packager
  #
  # This class stores the new repositories and services added during
  # installation or upgrade. It can be used together with the
  # OriginalRepositorySetup class to find the old and new repositories.
  #
  # @since 4.4.42
  class NewRepositorySetup
    include Yast::Logger
    include Singleton

    attr_reader :repositories, :services

    # constructor, initialize the stored lists to empty lists
    def initialize
      @repositories = []
      @services = []
    end

    # Store a repository name
    #
    # @param repo_alias [String] Repository alias
    def add_repository(repo_alias)
      log.info "Added #{repo_alias.inspect} to new repositories"
      repositories << repo_alias
    end

    # Store a service name
    #
    # @param service_name [String] Name of the service
    def add_service(service_name)
      log.info "Added #{service_name.inspect} to new services"
      services << service_name
    end
  end
end
