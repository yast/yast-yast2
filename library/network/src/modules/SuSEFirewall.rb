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
# File:        modules/SuSEFirewall.rb
# Authors:     Markos Chandras <mchandras@suse.de>, Karol Mroz <kmroz@suse.de>
#
# $Id$
#
# Module for handling SuSEfirewall2 or FirewallD
require "yast"
require "network/susefirewalld"
require "network/susefirewall2"

module Yast
  class SuSEFirewallMultipleBackends < StandardError
    def initialize(message)
      super message
    end
  end

  # Factory for construction of appropriate firewall object based on
  # desired backend.
  class FirewallClass < Module
    include Yast::Logger
    Yast.import "PackageSystem"

    # Use same hash for package names and services
    FIREWALL_BACKENDS = {
      sf2: "SuSEfirewall2",
      fwd: "firewalld"
    }.freeze

    # Check if backend is installed on the system.
    #
    # @param backend_sym [Symbol] Firewall backend
    # @return [Boolean] True if backend is installed.
    def self.backend_available?(backend_sym)
      # SF2 has it's own method of checking if it's installed. This is
      # used internally by SF2. Here, we simply care if the package
      # is present on the system.
      PackageSystem.Installed(FIREWALL_BACKENDS[backend_sym])
    end

    # Obtain backends which are installed on the system
    #
    # @return [Array<Symbol>] List of installed backends.
    def self.installed_backends
      backends = []

      FIREWALL_BACKENDS.each_key { |k| backends << k if backend_available?(k) }

      backends
    end

    # Obtain list of enabled backends.
    #
    # @return [Array<Symbol>] List of enabled backends.
    def self.enabled_backends
      Yast.import "Service"

      backends = []

      installed_backends.each do |b|
        backends << b if Service.Enabled(FIREWALL_BACKENDS[b])
      end

      backends
    end

    # Obtain running backend on the system.
    #
    # @return [Array<Symbol>] List of running backends.
    def self.running_backends
      Yast.import "Service"

      backends = []

      installed_backends.each { |b| backends << b if Service.Active(FIREWALL_BACKENDS[b]) }

      # In theory this should only return an Array with only one element in it
      # since FirewallD and SF2 systemd service files conflict with each other.
      backends
    end

    def self.create(backend_sym = nil)
      Yast.import "Mode"

      # Old testsuite
      if Mode.testsuite
        # For the old testsuite, always generate SF2 instance. FirewallD tests
        # will be committed later on but they will only affect the new
        # testsuite
        SuSEFirewall2Class.new

      # If backend is specificed, go ahead and create an instance. Otherwise, try
      # to detect which backend is enabled and create the appropriate instance.
      elsif backend_sym == :sf2
        SuSEFirewall2Class.new
      elsif backend_sym == :fwd
        SuSEFirewalldClass.new
      else
        begin
          # Only one running backend is permitted.
          raise SuSEFirewallMultipleBackends if running_backends.size > 1

          # If both firewalls are enabled, then make SF2 the default one and
          # emit a warning
          if running_backends.size == 0 && enabled_backends.size > 1
            Builtins.y2warning("Both SuSEfirewall2 and firewalld services are enabled. " \
                               "Defaulting to SuSEfirewall2")
            enabled_backends[0] = :sf2
          end

          # Set a good default. The running one takes precedence over the enabled one.
          selected_backend = running_backends[0] ? running_backends[0] : enabled_backends[0]
          selected_backend = :sf2 if selected_backend.to_s.empty? # SF2 still the default

          if selected_backend == :fwd
            # SuSEFirewalld instance is only generated if firewalld is running.
            SuSEFirewalldClass.new
          else
            # All other cases, we generate SF2 instance. This is still our default afterall.
            SuSEFirewall2Class.new
          end
        rescue SuSEFirewallMultipleBackends
          # This should never happen since FirewallD and SF2 systemd services
          # conflict with each other
          Builtins.y2error("Multiple firewall backends are running. One needs to be shutdown to continue.")
          # Re-raise it
          raise SuSEFirewallMultipleBackends
        end
      end
    end
  end

  SuSEFirewall = FirewallClass.create
  SuSEFirewall.main if SuSEFirewall.is_a?(SuSEFirewall2Class)
end
