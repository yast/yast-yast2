# ***************************************************************************
#
# Copyright (c) 2002 - 2014 Novell, Inc.
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

    ENABLED = 'enabled'
    DISABLED = 'disabled'

    def initialize
      @services = {}
    end

    def reset
      @services = {}
    end

    # Marks the given service as enabled and returns all currently
    # enabled services
    #
    # @param [String] service name
    # @return [Array <String>] list of enabled services
    def enable_service(service)
      check_service(service)
      @services[service] = ENABLED
      enabled_services
    end

    # Marks the given service as disabled and returns all currently
    # disabled services
    #
    # @param [String] service name
    # @return [Array <String>] list of enabled services
    def disable_service(service)
      check_service(service)
      @services[service] = DISABLED
      disabled_services
    end

    # Returns all services currently marked as enabled
    #
    # @return [Array <String>] list of enabled services
    def enabled_services
      @services.select{|service, status| status == ENABLED}.keys
    end

    # Returns all services currently marked as disabled
    #
    # @return [Array <String>] list of disabled services
    def disabled_services
      @services.select{|service, status| status == DISABLED}.keys
    end

  private

    # Checks the given service
    # Raises an exception in case of an error
    def check_service(service)
      if service.nil? || service.empty?
        raise ArgumentError.new("Wrong service name #{service} to enable")
      end
    end
  end

  ServicesProposal = ServicesProposalClass.new
end
