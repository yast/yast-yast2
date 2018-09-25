# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "yast"
require "network/susefirewalld"
require "network/susefirewall2"

Yast.import "Service"
Yast.import "PackageSystem"
Yast.import "Mode"

module Yast
  class SuSEFirewallMultipleBackends < StandardError
    DEFAULT_MESSAGE = "Multiple firewall backends are running. " \
      "One needs to be shutdown to continue.".freeze
    def initialize(message = DEFAULT_MESSAGE)
      super message
    end
  end

  # Factory for construction of appropriate firewall object based on
  # desired backend.
  class FirewallChooser
    include Yast::Logger

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
      FIREWALL_BACKENDS.select { |b, _p| backend_available?(b) }.keys
    end

    # Obtain list of enabled backends.
    #
    # @return [Array<Symbol>] List of enabled backends.
    def self.enabled_backends
      installed_backends.select { |b| Service.Enabled(FIREWALL_BACKENDS[b]) }
    end

    # Obtain running backend on the system.
    #
    # @note In theory this should only return an Array with only one element in it
    #   since FirewallD and SF2 systemd service files conflict with each other.
    #
    # @return [Array<Symbol>] List of running backends.
    def self.running_backends
      installed_backends.select { |b| Service.Active(FIREWALL_BACKENDS[b]) }
    end

    # Return an instance of the firewall given or detected
    #
    # @return [SuSEFirewall2Class, SuSEFirewalldClass]
    def self.choose(backend_sym = nil)
      backend = backend_sym || detect
      # For the old testsuite, always generate SF2 instance. FirewallD tests
      # will be committed later on but they will only affect the new
      # testsuite

      # If backend is specificed, go ahead and create an instance. Otherwise, try
      # to detect which backend is enabled and create the appropriate instance.
      backend = detect unless backend

      backend == :sf2 ? SuSEFirewall2Class.new : SuSEFirewalldClass.new
    end

    # Determine which firewall should be selected as the backend depending on
    # which one is enabled, running and/or installed. SuSEfirewall2 is the
    # predefined one in case there is no way to decide.
    #
    # @raise [SuSEFirewallMultipleBackends] if firewalld and SuSEfirewalld2 are
    #   running
    # @return [Symbol] the backend that should be used
    def self.detect
      # Old testsuite
      return :sf2 if Mode.testsuite

      # Only one running backend is permitted.
      raise SuSEFirewallMultipleBackends if running_backends.size > 1

      # If both firewalls are enabled, then make SF2 the default one and
      # emit a warning
      if running_backends.empty? && enabled_backends.size > 1
        Builtins.y2warning("Both SuSEfirewall2 and firewalld services are enabled. " \
                            "Defaulting to SuSEfirewall2")
        enabled_backends[0] = :sf2
      end

      # Set a good default. The running one takes precedence over the enabled one.
      selected_backend = running_backends[0] ? running_backends[0] : enabled_backends[0]
      # Fallback to the first installed backend or to SuSEfirewall2 if not
      selected_backend = (installed_backends.first || :sf2) if selected_backend.to_s.empty?

      return selected_backend

    rescue SuSEFirewallMultipleBackends
      # This should never happen since FirewallD and SF2 systemd services
      # conflict with each other
      Builtins.y2error("Multiple firewall backends are running. One needs to be shutdown to continue.")
      # Re-raise it
      raise SuSEFirewallMultipleBackends
    end
  end
end
