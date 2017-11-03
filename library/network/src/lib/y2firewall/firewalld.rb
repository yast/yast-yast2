# encoding: utf-8
#
# ***************************************************************************
#
# Copyright (c) 2017 SUSE LLC.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 or 3 of the GNU General
# Public License as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com
#
# ***************************************************************************

require "y2firewall/firewalld/api"
require "singleton"

Yast.import "PackageSystem"

module Y2Firewall
  # Main class to interact with Firewalld
  class Firewalld
    include Singleton
    include Yast::Logger
    extend Forwardable

    # Y2Firewall::Firewalld::Api instance
    attr_accessor :api

    PACKAGE = "firewalld".freeze
    SERVICE = "firewalld".freeze

    def_delegators :@api, :enable!, :disable!

    # Constructor
    def initialize
      @api = Y2Firewall::Firewalld::Api.new
    end

    # Return whether firewalld is running or not
    # @return [Boolean] true if it is running; false otherwise
    def running?
      api.running?
    end

    # Return wheter the firewalld package is installed or not
    #
    # @return [Boolean] true if it is installed; false otherwise
    def installed?
      return true if @installed

      @installed = Yast::PackageSystem.Installed(PACKAGE)
    end

    # Chech whether the firewalld service is enable or not
    #
    # @return [Boolean] true if it is enable; false otherwise
    def enabled?
      return false unless installed?

      Yast::Service.Enabled?(SERVICE)
    end

    # Restart the firewalld service
    #
    # @return [Boolean] true if it has been restarted; false otherwise
    def restart!
      return false unless installed?

      Yast::Service.Restart(SERVICE)
    end

    # Stop the firewalld service
    #
    # @return [Boolean] true if it has been stopped; false otherwise
    def stop!
      return false if !installed? || !running?

      Yast::Service.Stop(SERVICE)
    end

    # Start the firewalld service
    #
    # @return [Boolean] true if it has been started; false otherwise
    def start!
      return false if !installed? || running?

      Yast::Service.Start(SERVICE)
    end
  end
end
