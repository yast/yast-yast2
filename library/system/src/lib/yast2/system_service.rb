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
  #
  # Additionally, this class does not modify the underlying system until the #save
  # method is called.
  #
  # @example Enabling a service
  #   cups = SystemService.find("cups")
  #   cups.start_mode = :boot
  #   cups.save
  #
  # @example Activating a service
  #   cups = SystemService.find("cups")
  #   cups.active = true
  #   cups.save
  #
  # @example Ignoring status changes on 1st stage
  #   cups = SystemService.find("cups")
  #   cups.active = true
  #   cups.save(ignore_status: true)
  class SystemService
    extend Forwardable

    # @return [Yast::SystemdService]
    attr_reader :service

    def_delegators :@service, :running?, :start, :stop, :restart, :name, :description

    # @!method state
    #
    # @return [String]
    def_delegator :@service, :active_state, :state

    # @!method substate
    #
    # @return [String]
    def_delegator :@service, :sub_state, :substate

    class << self
      # Find a service
      #
      # @param name [String] Service name
      # @return [SystemService,nil] System service or nil when not found
      def find(name)
        new(Yast::SystemdService.find(name))
      end

      # Finds service names
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
      @changes = {}
    end

    # Returns the start mode
    #
    # See {#start_modes} to find out the supported modes for a given service (usually :on_boot,
    # :manual and, in some cases, :on_demand).
    #
    # When the service (:on_boot) and the socket (:on_demand) are enabled, the start mode is translated
    # to :on_boot.
    #
    # @return [Symbol] Start mode (:on_boot, :on_demand, :manual)
    def start_mode
      new_value_for(:start_mode) || current_start_mode
    end

    # Sets the service start mode
    #
    # See {#start_modes} to find out the supported modes for a given service (usually :on_boot,
    # :manual and, in some cases, :on_demand). The given value will be applied after calling #save.
    #
    # @see #start_modes
    # @raise ArgumentError when mode is not valid
    def start_mode=(mode)
      if !start_modes.include?(mode)
        raise ArgumentError, "Invalid start mode: '#{mode}' for service '#{service.name}'"
      end

      if mode == current_start_mode
        unregister_change(:start_mode)
      else
        register_change(:start_mode, mode)
      end
    end

    # Sets whether the service should be active or not
    #
    # The given value will be applied after calling #save.
    #
    # @param value [Boolean] true to set this service as active
    def active=(value)
      if value == active?
        unregister_change(:active)
      else
        register_change(:active, value)
      end
    end

    # Determine whether the service will be active after calling #save
    #
    # @return [Boolean] true if the service must be active; false otherwise
    def active
      return new_value_for(:active) if changed_value?(:active)
      service.active?
    end

    alias_method :active?, :active

    # Saves changes to the underlying system
    #
    # @param set_status [Boolean] Do not change service status. Useful when running on 1st stage.
    def save(ignore_status: false)
      save_start_mode
      set_current_status unless ignore_status
      reload
    end

    # Reverts stored changes
    def reload
      clear_changes
      @current_start_mode = nil
    end

    # Determines whether the system has been changed or not
    #
    # @return [Boolean] true if the system has been changed
    def changed?
      !changes.empty?
    end

    # Returns the list of supported start modes
    #
    # * :on_boot:   The service will be started when the system boots.
    # * :manual: The service is disabled and it will be started manually.
    # * :on_demand: The service will be started on demand (using a Systemd socket).
    #
    # @return [Array<Symbol>] List of supported modes.
    def start_modes
      return @start_modes if @start_modes
      @start_modes = [:on_boot, :manual]
      @start_modes << :on_demand if socket
      @start_modes
    end

    # Terms to search for this service
    #
    # In case the service has an associated socket, the socket name
    # is included as search term.
    #
    # @return [Array<String>] e.g., #=> ["tftp.service", "tftp.socket"]
    def search_terms
      terms = [service.id]
      terms << socket.id if socket
      terms
    end

    # Determines whether a value has been changed
    #
    # @return [Boolean] true if the value has been changed; false otherwise
    def changed_value?(key)
      changes.key?(key)
    end

  private

    # @return [Hash<String,Object>]
    attr_reader :changes

    # Get the current start_mode
    def current_start_mode
      @current_start_mode ||=
        if service.enabled?
          :on_boot
        elsif socket && socket.enabled?
          :on_demand
        else
          :manual
        end
    end

    # Sets start mode to the underlying system
    def save_start_mode
      return unless changed_value?(:start_mode)
      case new_value_for(:start_mode)
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

    # Sets service status
    def set_current_status
      if new_value_for(:active) && !service.active?
        service.start
      elsif new_value_for(:active) == false && service.active?
        service.stop
      end
    end

    # Returns the associated socket
    #
    # @return [Yast::SystemdSocketClass::Socket]
    def socket
      service && service.socket
    end

    # Unregisters change for a given key
    #
    # @param [Symbol] Change key
    def unregister_change(key)
      changes.delete(key)
    end

    # Registers change for a given key
    #
    # @param [Symbol] Change key
    # @param [Object] New value
    def register_change(key, new_value)
      changes[key] = new_value
    end

    # Clears changes
    def clear_changes
      changes.clear
    end

    # Returns the new value for a given key
    #
    # @param [Symbol] Change key
    # @return [Object] New value
    def new_value_for(key)
      return nil unless changed_value?(key)
      changes[key]
    end
  end
end
