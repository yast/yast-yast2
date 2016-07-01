# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2002 - 2016 Novell, Inc.
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
#
# File:	modules/SuSEFirewallServices.rb
# Package:	Firewall Services, Ports Aliases.
# Summary:	Definition of Supported Firewall Services and Port Aliases.
# Authors:	Markos Chandras <mchandras@suse.de>
#
# Global Definition of Firewall Services
# Manages services for SuSEFirewall2 and FirewallD

require "yast"
require "network/susefirewall2services"
require "network/susefirewalldservices"

module Yast
  class FirewallServicesClass < Module
    include Yast::Logger

    # Create appropriate firewall services class based on factors such as which
    # backend is selected by user or running on the system.
    #
    # @note If the backend_sym parameter is :fwd (ie, FirewallD is the desired
    # @note firewall backend), then the method will also start the FirewallD service.
    #
    # @param backend_sym [Symbol] if not nil, explicitely select :sf2 or :fwd
    # @return SuSEFirewall2ServicesClass or SuSEfirewalldServicesClass instance
    def self.create(backend_sym = nil)
      Yast.import "SuSEFirewall"

      # If backend is specificed, go ahead and create an instance. Otherwise, try
      # to detect which backend is enabled and create the appropriate instance.
      case backend_sym
      when :sf2
        SuSEFirewall2ServicesClass.new
      when :fwd
        # We need to start the backend first
        if !SuSEFirewall.IsStarted()
          log.info "Starting the FirewallD service"
          SuSEFirewall.StartServices()
        end
        SuSEFirewalldServicesClass.new
      when nil
        # Instantiate one based on the running backend
        if SuSEFirewall.is_a?(SuSEFirewall2Class)
          SuSEFirewall2ServicesClass.new
        else
          SuSEFirewalldServicesClass.new
        end
      else
        raise "Invalid symbol for firewall backend #{backend_sym.inspect}"
      end
    end
  end
end

Yast::SuSEFirewallServices = Yast::FirewallServicesClass.create
Yast::SuSEFirewallServices.main if Yast::SuSEFirewallServices.is_a?(Yast::SuSEFirewall2ServicesClass)
