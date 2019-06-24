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
require "yast2/systemd/service"

module Yast2
  # This class represents a service from a high level point of view
  #
  # When talking about systemd, it might happen that a service could have an associated
  # socket (or path or timer). This class is able to group those units and offer an API
  # to handle them together.
  #
  # See also {file:library/systemd/doc/services_and_sockets.md}.
  #
  # @note All changes performed over an object of this class are not applied into the
  #   underlying system until the {#save} method is called.
  #
  # @example Enabling a service
  #   cups = SystemService.find("cups")
  #   cups.start_mode = :on_boot
  #   cups.save
  #
  # @example Activating a service
  #   cups = SystemService.find("cups")
  #
  #   cups.currently_active? #=> false
  #   cups.active?           #=> false
  #
  #   cups.start
  #
  #   cups.currently_active? #=> false
  #   cups.active?           #=> true
  #
  #   cups.save
  #
  #   cups.currently_active? #=> true
  #   cups.active?           #=> true
  #
  # @example Changing start mode
  #   cups = SystemService.find("cups")
  #   cups.start_mode = :on_demand
  #
  #   cups.current_start_mode #=> :on_boot
  #   cups.start_mode         #=> :on_demand
  #
  #   cups.save
  #
  #   cups.current_start_mode #=> :on_demand
  #   cups.start_mode         #=> :on_demand
  #
  # @example Ignoring status changes (useful when changing the service on 1st stage)
  #   cups = SystemService.find("cups")
  #   cups.start
  #
  #   cups.currently_active? #=> false
  #   cups.active?           #=> true
  #
  #   cups.save(keep_state: true)
  #
  #   cups.currently_active? #=> false
  class SystemService
    extend Forwardable

    # Error when a service is not found
    class NotFoundError < RuntimeError; end

    # @return [Yast2::Systemd::Service]
    attr_reader :service

    # @return [Hash<Symbol, Object>] Errors when trying to write changes to the underlying system.
    #   * :active [Boolean] whether the service should be active after saving
    #   * :start_mode [Symbol] start mode the service should have after saving
    attr_reader :errors

    # @return [Symbol, nil] :start, :stop, :restart or :reload. It returns nil
    #   if no action has been requested yet.
    attr_reader :action

    # @!method support_reload?
    #
    # @return [Boolean]
    def_delegator :@service, :can_reload?, :support_reload?

    # @!method name
    #   @see Yast2::Systemd::Service#name
    #   @return [String]
    # @!method static?
    #   @see Yast2::Systemd::Service#static?
    #   @return [Boolean]
    # @!method running?
    #   @see Yast2::Systemd::Service#running?
    #   @return [Boolean]
    # @!method description
    #   @see Yast2::Systemd::Service#description
    #   @return [String]
    def_delegators :@service, :name, :static?, :running?, :description

    class << self
      # Finds a service by its name
      #
      # @param name [String] service name with or without extension (e.g., "cups" or "cups.service")
      # @return [SystemService, nil] nil if the service is not found
      def find(name)
        systemd_service = Yast2::Systemd::Service.find(name)
        return nil unless systemd_service

        new(systemd_service)
      end

      # Finds a service by its name
      #
      # @param name [String] service name
      #
      # @raise [NotFoundError] if the service is not found
      # @return [SystemService]
      def find!(name)
        system_service = find(name)
        raise(NotFoundError, name) unless system_service

        system_service
      end

      # Builds a service instance based on the given name
      #
      # @param name [String] Service name
      # @return [SystemService] System service based on the given name
      #
      # @see Yast2::Systemd::Service.build
      def build(name)
        new(Yast2::Systemd::Service.build(name))
      end

      # Finds a set of services by their names
      #
      # @param names [Array<String>] service names to find
      #
      # @return [Array<SystemService>] when not found then the SystemService.servie is nil for the respective service in the list
      def find_many(names)
        Yast2::Systemd::Service.find_many(names).map { |s| new(s) }
      end
    end

    # Constructor
    #
    # @param service [Yast2::Systemd::Service]
    def initialize(service)
      @service = service
      @changes = {}
      @errors = {}
    end

    # Determines whether the service exists in the underlying system
    #
    # @return [Boolean] true if it exists; false otherwise.
    def found?
      !service.not_found?
    end

    # State of the service
    #
    # In case the service is not active but socket is, the socket state is considered
    #
    # @return [String] all possible active_state values of systemd
    def state
      return socket.active_state if socket_active? && !service.active?

      service.active_state
    end

    # Substate of the service
    #
    # In case the service is not active but socket is, the socket substate is considered
    #
    # @return [String] all possible sub_state values of systemd
    def substate
      return socket.sub_state if socket_active? && !service.active?

      service.sub_state
    end

    # Gets the current start_mode
    #
    # @note This is the start mode that the service currently has in the system.
    #   Method {#start_mode} returns the last start mode that has been set to
    #   the service, but that value has not been applied yet (only changed in memory).
    #
    # @return [Symbol] :on_boot, :on_demand, :manual
    def current_start_mode
      return @current_start_mode unless @current_start_mode.nil?

      @current_start_mode =
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
    def currently_active?
      service.active? || socket_active?
    end

    # Returns the list of supported start modes for this service (if a socket
    # unit is available, :on_demand is supported, otherwise not)
    #
    # * :on_boot:   The service will be started when the system boots.
    # * :on_demand: The service will be started on demand.
    # * :manual:    The service is disabled and it will be started manually.
    #
    # @note When the service does not exist in the underlying system (for instance,
    # during 1st stage) all possible start modes are returned, as there is no way
    # to find out which of them are supported.
    #
    # @return [Array<Symbol>] List of supported modes.
    def start_modes
      @start_modes = [:on_boot, :manual, :on_demand] unless found?
      return @start_modes if @start_modes

      @start_modes = [:manual]
      @start_modes << :on_boot unless service.static?
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

      register_change(:start_mode, mode)
    end

    # Whether the service supports :on_demand start mode
    #
    # @return [Boolean]
    def support_start_on_demand?
      start_modes.include?(:on_demand)
    end

    # Whether the service supports :on_boot start mode
    #
    # @return [Boolean]
    def support_start_on_boot?
      start_modes.include?(:on_boot)
    end

    # Whether the service will be active after calling {#save}
    #
    # @note This is a temporary value (not saved yet). Use {#currently_active?} to get the actual
    #   active value of the service in the system.
    #
    # @return [Boolean] true if the service must be active; false otherwise
    def active?
      new_value = new_value_for(:active)
      new_value.nil? ? currently_active? : new_value
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
    # @return [void]
    def start
      self.active = true
      self.action = :start
    end

    # Sets the service to be stopped after calling {#save}
    #
    # @see #active=
    #
    # @return [void]
    def stop
      self.active = false
      self.action = :stop
    end

    # Sets the service to be restarted after calling {#save}
    #
    # @return [void]
    def restart
      register_change(:active, true)
      self.action = :restart
    end

    # Sets the service to be reloaded after calling {#save}
    #
    # @return [void]
    def reload
      register_change(:active, true)
      self.action = :reload
    end

    # Saves changes into the underlying system
    #
    # @note All cached changes are reset and the underlying service is refreshed
    #   when the changes are correctly applied.
    #
    # @raise [Yast2::Systemctl::Error] if the service cannot be refreshed
    #
    # @param keep_state [Boolean] Do not change service status. Useful when running on 1st stage.
    # @return [Boolean] true if the service was saved correctly; false otherwise.
    def save(keep_state: false)
      clear_errors
      save_start_mode
      perform_action unless keep_state

      errors.none? && reset && refresh!
    end

    # Reverts cached changes
    #
    # The underlying service is not refreshed. For that, see {#refresh}.
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
      refresh!
    rescue Yast2::Systemctl::Error
      false
    end

    # Refreshes the underlying service
    #
    # @raise [Yast2::Systemctl::Error] if the service cannot be refreshed
    #
    # @return [Boolean] true if the service was refreshed correctly
    def refresh!
      service.refresh!
      @start_modes = nil
      @current_start_mode = nil

      true
    end

    # Whether there is any cached change that will be applied by calling {#save}.
    #
    # Some specific change can be checked by using the key parameter.
    #
    # @example
    #   service.changed?(:start_mode)
    #
    # @return [Boolean]
    def changed?(key = nil)
      key ? changed_value?(key) : any_change?
    end

  private

    # @!method action=(value)
    #
    # Action to perform when the service is saved (see {#save})
    #
    # @param value [Symbol] :start, :stop, :restart, :reload
    attr_writer :action

    # @return [Hash<Symbol, Object>]
    attr_reader :changes

    # Sets whether the service should be active or not
    #
    # The given value will be applied after calling {#save}.
    #
    # @param value [Boolean] true to set this service as active
    def active=(value)
      register_change(:active, value)
    end

    # Sets start mode to the underlying system
    def save_start_mode
      return unless changed?(:start_mode)

      result =
        case changes[:start_mode]
        when :on_boot
          service.enable && (socket ? socket.disable : true)
        when :on_demand
          disable_service && (socket ? socket.enable : false)
        when :manual
          disable_service && (socket ? socket.disable : true)
        end

      register_error(:start_mode) unless result
    end

    # Performs the indicated action (if any) in the underlying system
    #
    # @note In case the action cannot be performed, an error is registered,
    #   see {#register_error}.
    #
    # @return [Boolean] true if the service is correctly save; false otherwise.
    def perform_action
      return true unless action

      result = send("perform_#{action}")
      register_error(:active) if result == false

      result

      # FIXME: SystemdService#{start, stop, etc} calls to refresh! internally, so when
      # this exception is raised we cannot distinguish if the action is failing or
      # refresh! is failing. For SP1, refresh! should raise a new kind of exception.
    rescue Yast2::Systemctl::Error
      register_error(:active)
      false
    end

    # Starts the service in the underlying system
    #
    # @raise [Yast2::Systemctl::Error] if some service command fails
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
    # @raise [Yast2::Systemctl::Error] if some service command fails
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
    # @raise [Yast2::Systemctl::Error] if some service command fails
    #
    # @return [Boolean] true if the service was correctly restarted
    def perform_restart
      perform_stop && perform_start
    end

    # Reloads the service in the underlying system
    #
    # @note The service is simply restarted when it does not support reload action.
    #
    # @raise [Yast2::Systemctl::Error] if some service command fails
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
    # @return [Yast2::Systemd::Socket]
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

    # Registers change for a given key
    #
    # @param key [Symbol] Change key
    # @param new_value [Object] New value
    def register_change(key, new_value)
      changes[key] = new_value
    end

    # Clears changes
    def clear_changes
      changes.clear
    end

    # Returns the new value for a given key
    #
    # @param key [Symbol] Change key
    # @return [Object] New value
    def new_value_for(key)
      changes[key]
    end

    # Correspondence between changed values and methods to calculate their current value
    CURRENT_VALUE_METHODS = {
      active:     :currently_active?,
      start_mode: :current_start_mode
    }.freeze

    # Determines whether a value has been changed
    #
    # @param key [Symbol] Changed value
    # @return [Boolean] true if it has changed; false otherwise.
    def changed_value?(key)
      new_value = new_value_for(key)
      return false if new_value.nil?

      new_value != send(CURRENT_VALUE_METHODS[key])
    end

    # Determines whether some value has been changed
    #
    # @return [Boolean] true if it has changed; false otherwise.
    def any_change?
      CURRENT_VALUE_METHODS.keys.any? { |k| changed_value?(k) }
    end

    # Disable the service unless it is static
    #
    # @note It does not try to disable the service when it is an static one.
    #
    # @return [Boolean] false if the operation failed
    def disable_service
      return true if service.static?

      service.disable
    end
  end
end
