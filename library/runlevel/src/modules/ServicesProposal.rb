# ***************************************************************************
#
# Copyright (c) 2014 Novell, Inc.
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
###

#
# Holds information about services that were enabled or disabled during
# installation. At this time it's only used for exporting the configuration
# for AutoYast at the end of the installation.
#

require "yast"

module Yast
  class ServicesProposalClass < Module
    include Yast::Logger

    def initialize
      @services = {}
    end

    def reset
      @services = {}
    end

    # Marks the given service as enabled
    #
    # @param [String] service name
    def enable_service(service)
      check_service(service)
      @services[service] = :enabled
    end

    # Marks the given service as disabled
    #
    # @param [String] service name
    def disable_service(service)
      check_service(service)
      @services[service] = :disabled
    end

    # Returns all services currently marked as enabled
    #
    # @return [Array <String>] list of enabled services
    def enabled_services
      @services.select { |_service, status| status == :enabled }.keys
    end

    # Returns all services currently marked as disabled
    #
    # @return [Array <String>] list of disabled services
    def disabled_services
      @services.select { |_service, status| status == :disabled }.keys
    end

  private

    # Checks the given service
    # Raises an exception in case of an error
    def check_service(service)
      return if service && !service.empty?

      raise ArgumentError, "Wrong service name '#{service.inspect}'"
    end
  end

  ServicesProposal = ServicesProposalClass.new
end
