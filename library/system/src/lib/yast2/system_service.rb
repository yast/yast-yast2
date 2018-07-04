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

require "forwardable"
Yast.import "SystemdService"

module Yast2
  # This class represents a system service
  #
  # When talking about systemd, it might happen that a service is compose by a set of units
  # (services, sockets, paths and so on). This class is able to group those units and
  # offer an API to handle them together.
  class SystemService
    extend Forwardable

    # @return [Yast::SystemdService]
    attr_reader :service

    def_delegators :@service, :running?, :start, :stop, :restart, :active?,
      :active_state, :sub_state, :description

    class << self
      # Find a service
      #
      # @param name [String] Service name
      # @return [SystemService,nil] System service or nil when not found
      def find(name)
        new(Yast::SystemdService.find(name))
      end

      # Find service names
      #
      # This method finds a set of system services. Currently it is just a wrapper around
      # SystemdService.find_many.
      #
      # @param names [Array<String>] Service names to find
      # @return [Array<SystemService>] Found system services
      def find_many(names)
        Yast::SystemdService.find_many(names).compact.map { |s| new(s) }
      end
    end

    # @param service [Yast::SystemdServiceClass::Service]
    def initialize(service)
      @service = service
    end

    # Returns socket associated with service or nil if there is no such socket
    #
    # @return [Yast::SystemdSocketClass::Socket]
    def socket
      return @socket if @socket

      # not triggered
      socket_name = service.properties.triggered_by
      return unless socket_name

      socket_name = socket_name[/\S+\.socket/]
      return unless socket_name # triggered by non-socket

      @socket = Yast::SystemdSocket.find(socket_name)
    end

    # Determine whether the service has an associated socket
    #
    # @return [Boolean] true if an associated socket exists; false otherwise.
    def socket?
      !socket.nil?
    end

    # Return the start mode
    #
    # See {#start_modes} to find out the supported modes for a given service (usually :on_boot,
    # :manual and, in some cases, :on_demand).
    #
    # When the service (:on_boot) and the socket (:on_demand) are enabled, the start mode is translated
    # to :on_boot.
    #
    # @return [Symbol] Start mode (:on_boot, :on_demand, :manual)
    def start_mode
      return :on_boot if service.enabled?
      return :on_demand if socket && socket.enabled?
      :manual
    end

    # Set the service start mode
    #
    # See {#start_modes} to find out the supported modes for a given service (usually :on_boot,
    # :manual and, in some cases, :on_demand).
    #
    # @see #start_modes
    # @raise ArgumentError when mode is not valid
    def start_mode=(mode)
      if !start_modes.include?(mode)
        raise ArgumentError, "Invalid start mode: '#{mode}' for service '#{service.name}'"
      end

      case mode
      when :on_boot
        service.enable
        socket.disable
      when :on_demand
        service.disable
        socket.enable
      when :manual
        service.disable
        socket.disable
      end
    end

    # Return the list of supported start modes
    #
    # * :on_boot:   The service will be started when the system boots.
    # * :manual: The service is disabled and it will be started manually.
    # * :on_demand: The service will be started on demand (using a Systemd socket).
    #
    # @return [Array<Symbol>] List of supported modes.
    def start_modes
      return @start_modes if @start_modes
      @start_modes = [:on_boot, :manual]
      @start_modes << :on_demand if socket?
      @start_modes
    end
  end
end
