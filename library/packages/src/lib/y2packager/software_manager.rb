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

require "y2packager/repository"
require "y2packager/libzypp_backend"
require "y2packager/software_search"

module Y2Packager
  # This class represents the software management subsystem
  #
  # It allows managing software repositories, installing/removing software, and so on.
  #
  # @example Initialize the software management subsystem
  #   software = SoftwareManagement.new(LibzyppBackend.new)
  #   software.probe
  #
  # @example Convenience method to initialize the software manager
  #   SoftwareManager.probe
  #   SoftwareManager.current #=> #<Y2Packager::SoftwareManager...>
  #
  class SoftwareManager
    # @return [Array<Backend>] List of known backends
    attr_reader :backends

    class << self
      # Returns a SoftwareManager instance and keeps the reference for the future
      #
      # @note At this time, it always initializes the system using the LibzyppBackend.
      # @return [SoftwareManagement] A SoftwareManagement instance for the current system
      def current
        @current ||= new([LibzyppBackend.new])
      end

      def reset
        @current = nil
      end
    end

    # @param backends [Array<Backend>] List of backends to use
    def initialize(backends)
      @backends = backends
    end

    # Initialize the software subsystem
    def probe
      backends.each(&:probe)
    end

    # Commits the changes defined in the software proposal
    #
    # @param [SoftwareProposal]
    def commit(_proposal)
      # ask the backends to install the given packages/apps
      raise NotImplementedError
    end

    # List of repositories from all the backends
    #
    # @return [Array<Repository>] Defined repositories from all backends
    def repositories
      backends.each_with_object([]) do |backend, all|
        all.concat(backend.repositories)
      end
    end

    # Returns a search object which includes all backends
    #
    # @todo Allow disabling any backend.
    #
    # @return [SoftwareSearch]
    def search
      SoftwareSearch.new(*backends)
    end
  end
end
