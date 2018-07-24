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
  # Additionally, this class does not modify the underlying system until the {#save}
  # method is called.
  #
  # @example Enabling a service
  #   cups = SystemService.find("cups")
  #   cups.start_mode = :on_boot
  #   cups.save
  #
  # @example Activating a service
  #   cups = SystemService.find("cups")
  #   cups.start
  #   cups.save
  #
  # @example Ignoring status changes on 1st stage
  #   cups = SystemService.find("cups")
  #   cups.start
  #   cups.save(keep_state: true)
  class SystemService
    extend Forwardable

    # @return [Yast::SystemdServiceClass::Service]
    attr_reader :service

    # @return [Hash<Symbol,Object>] Errors when trying to write changes to the
    #   underlying system.
    attr_reader :errors

    # @return [Symbol, nil] :start, :stop, :restart or :reload. It returns nil
    #   if no action has been requested yet.
    attr_reader :action

    # @!method support_reload?
    #
    # @return [Boolean]
    def_delegator :@service, :can_reload?, :support_reload?

    def_delegators :@service, :name, :static?, :running?, :description

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

    # Constructor
    #
    # @param service [Yast::SystemdServiceClass::Service]
    def initialize(service)
      @service = service
      @changes = {}
      @errors = {}
    end

    # State of the service
    #
    # In case the service is not active but socket, the socket state is considered
    #
    # @return [String]
    def state
      return socket.active_state if socket_active? && !service.active?

      service.active_state
    end

    # Substate of the service
    #
    # In case the service is not active but socket, the socket substate is considered
    #
    # @return [String]
    def substate
      return socket.sub_state if socket_active? && !service.active?

      service.sub_state
    end

    # Gets the current start_mode (as read from the system)
    #
    # @return [Symbol] :on_boot, :on_demand, :manual
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

    # Whether the service is currently active in the system
    #
    # @return [Boolean]
    def current_active?
      service.active? || socket_active?
    end

    # Returns the list of supported start modes
    #
    # * :on_boot:   The service will be started when the system boots.
    # * :on_demand: The service will be started on demand.
    # * :manual:    The service is disabled and it will be started manually.
    #
    # @return [Array<Symbol>] List of supported modes.
    def start_modes
      return @start_modes if @start_modes
      @start_modes = [:on_boot, :manual]
      @start_modes << :on_demand if socket
      @start_modes
    end

    # Returns the start mode
    #
    # See {#start_modes} to find out the supported modes for a given service (usually :on_boot,
    # :manual and, in some cases, :on_demand).
    #
    # @note This is a temporary value (not saved yet). Use {#current_start_mode} to get the actual
    #   start mode of the service in the system.
    #
    # @return [Symbol] :on_boot, :on_demand, :manual
    def start_mode
      new_value_for(:start_mode) || current_start_mode
    end

    # Sets the service start mode
    #
    # See {#start_modes} to find out the supported modes for a given service (usually :on_boot,
    # :manual and, in some cases, :on_demand). The given value will be applied after calling {#save}.
    #
    # @see #start_modes
    #
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

    # Whether the service supports :on_demand start mode
    #
    # @return [Boolean]
    def support_start_on_demand?
      start_modes.include?(:on_demand)
    end

    # Whether the service will be active after calling {#save}
    #
    # @note This is a temporary value (not saved yet). Use {#current_active?} to get the actual
    #   active value of the service in the system.
    #
    # @return [Boolean] true if the service must be active; false otherwise
    def active?
      return new_value_for(:active) if changed_value?(:active)
      current_active?
    end

    # Keywords to search for this service
    #
    # In case the service has an associated socket, the socket name
    # is included as keyword.
    #
    # @return [Array<String>] e.g., #=> ["tftp.service", "tftp.socket"]
    def keywords
      keywords = [service.id]
      keywords << socket.id if socket
      keywords
    end

    # Sets the service to be started after calling {#save}
    #
    # @see #active=
    #
    # @return [Symbol] :start
    def start
      self.active = true
      self.action = :start
    end

    # Sets the service to be stopped after calling {#save}
    #
    # @see #active=
    #
    # @return [Symbol] :stop
    def stop
      self.active = false
      self.action = :stop
    end

    # Sets the service to be restarted after calling {#save}
    #
    # @return [Symbol] :restart
    def restart
      register_change(:active, true)
      self.action = :restart
    end

    # Sets the service to be reloaded after calling {#save}
    #
    # @return [Symbol] :reload
    def reload
      register_change(:active, true)
      self.action = :reload
    end

    # Saves changes into the underlying system
    #
    # @note Cached changes are reset and the underlying service is refreshed.
    #
    # @param keep_state [Boolean] Do not change service status. Useful when running on 1st stage.
    #
    # @return [Boolean] true if the service was saved correctly; false otherwise.
    def save(keep_state: false)
      clear_errors
      save_start_mode
      perform_action unless keep_state
      reset && refresh
    end

    # Reverts cached changes
    #
    # @return [Boolean] true if the service was reset correctly. Actually, the
    #   service always can be reset.
    def reset
      clear_changes
      @action = nil

      true
    end

    # Refreshes the underlying service
    #
    # @return [Boolean] true if the service was refreshed correctly; false otherwise.
    def refresh
      service.refresh!
      @start_modes = nil
      @current_start_mode = nil
      true
    rescue Yast::SystemctlError
      false
    end

    # Whether there is any cached change that will be applyied by calling {#save}.
    #
    # @return [Boolean]
    def changed?
      !changes.empty?
    end

    # Whether a specific value has been changed
    #
    # @return [Boolean]
    def changed_value?(key)
      changes.key?(key)
    end

  private

    # @!method action=(value)
    #
    # Action to perform when the service is saved (see {#save})
    #
    # @param value [Symbol] :start, :stop, :restart, :reload
    attr_writer :action

    # @return [Hash<String, Object>]
    attr_reader :changes

    # Sets whether the service should be active or not
    #
    # The given value will be applied after calling {#save}.
    #
    # @param value [Boolean] true to set this service as active
    def active=(value)
      if value == service.active?
        unregister_change(:active)
      else
        register_change(:active, value)
      end
    end

    # Sets start mode to the underlying system
    def save_start_mode
      return unless changes[:start_mode]

      result =
        case changes[:start_mode]
        when :on_boot
          service.enable && (socket ? socket.disable : true)
        when :on_demand
          service.disable && (socket ? socket.enable : true)
        when :manual
          service.disable && (socket ? socket.disable : true)
        end

      register_error(:start_mode) unless result
    end

    # Performs the indicated action (if any) in the underlying system
    #
    # @note In case the action cannot be performed, an error is registered,
    #   see {#register_error}.
    def perform_action
      return unless action

      result = send("perform_#{action}")

      register_error(:active) if result == false
    end

    # Starts the service in the underlying system
    #
    # @return [Boolean] true if the service was correctly started
    def perform_start
      result = true

      if socket && start_mode == :on_demand
        result &&= socket.start unless socket_active?
      else
        result &&= service.start unless service.active?
      end

      result
    end

    # Stops the service in the underlying system
    #
    # @return [Boolean] true if the service was correctly stopped
    def perform_stop
      result = true

      result &&= service.stop if service.active?
      result &&= socket.stop if socket_active?

      result
    end

    # Restarts the service in the underlying system
    #
    # @return [Boolean] true if the service was correctly restarted
    def perform_restart
      perform_stop && perform_start
    end

    # Reloads the service in the underlying system
    #
    # @note The service is simply restarted when it does not support reload action.
    #
    # @return [Boolean] true if the service was correctly reloaded
    def perform_reload
      return perform_restart unless support_reload?

      result = true

      result &&= socket.stop if socket_active? && start_mode != :on_demand
      result &&= service.active? ? service.reload : perform_start

      result
    end

    # Registers error information
    #
    # Stores the source of error and the value which caused it.
    #
    # @param key [Symbol] Source of error
    def register_error(key)
      errors[key] = changes[key]
    end

    # Clears registered errors
    def clear_errors
      @errors.clear
    end

    # Returns the associated socket
    #
    # @return [Yast::SystemdSocketClass::Socket]
    def socket
      service && service.socket
    end

    # Whether the associated socket (if any) is actived
    #
    # @return [Boolean]
    def socket_active?
      return false unless socket

      socket.active?
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
