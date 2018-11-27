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
require "yast2/system_service"

module Yast2
  # Class that represents several related services that need to be synchronized.
  # It mimics behavior of single {Yast2::SystemService}, but it adds possible states.
  class CompoundService
    include Yast::Logger

    # Managed services
    #
    # @return [Array<Yast2::SystemService>]
    attr_reader :services

    # Creates a new service composed by several services
    #
    # @param services [Array<Yast2::SystemService>]
    #
    # @example
    #   iscsi = Yast2::SystemService.find("iscsi")
    #   iscsid = Yast2::SystemService.find("iscsid")
    #   service = Yast2::CompoundService.new(iscsi, iscsid)
    def initialize(*services)
      if services.any? { |s| !s.is_a?(Yast2::SystemService) }
        raise ArgumentError, "Services can be only System Service - #{services.inspect}"
      end

      @services = services
    end

    # Saves all services
    #
    # @see Yast2::SystemService#save
    #
    # @return [Boolean] true if all services were correctly saved; false otherwise
    def save(keep_state: false)
      services.each { |s| s.save(keep_state: keep_state) }

      errors.empty?
    end

    # Whether the services are currently active
    #
    # @return [true, false, :inconsistent]
    #
    #   - `true`          when all services are active
    #
    #   - `false`         when no services are active
    #
    #   - `:inconsistent` when part of services are active and part not.
    #
    # @note It offers an additional value `:inconsistent` that is not in {Yast2::SystemService}
    def currently_active?
      return true if services.all?(&:currently_active?)
      return false if services.none?(&:currently_active?)
      :inconsistent
    end

    # Whether any service supports reload
    #
    # @see Yast2::SystemService#support_reload?
    #
    # @return [Boolean]
    def support_reload?
      services.any?(&:support_reload?)
    end

    # Possible start modes taking into account all services
    #
    # If a service supports :on_boot and :manual start modes, but another
    # service supports :on_demand too, the possible start modes will the
    # all of them: :on_boot, on_demand and :manual.
    #
    # @see Yast2::SystemService#start_modes
    #
    # @return [Array<Symbol>] start modes (:on_boot, :on_demand, :manual)
    def start_modes
      @start_modes ||= services.map(&:start_modes).reduce(:+).uniq
    end

    # Keywords that can be used to search for involved underlying units
    #
    # @see Yast2::SystemService#keywords
    #
    # @return [Array<String>]
    def keywords
      services.map(&:keywords).reduce(:+).uniq
    end

    # Action to perform over all services
    #
    # @see Yast2::SystemService#action
    #
    # @return [:start, :stop, :restart, :reload, nil]
    #
    #   - `:start`   starts all services. If a service is already active, does nothing.
    #                if a service has socket it starts socket instead of the service.
    #
    #   - `:stop`    stops all services. If a service is inactive, does nothing.
    #
    #   - `:restart` restarts all services. If a service is inactive, it is started.
    #
    #   - `:reload`  reloads all services that support it and restarts that does not
    #                support it. If service is inactive, it is started.
    #
    #   - `nil`      no action has been indicated. Does nothing.
    def action
      # TODO: check for inconsistencies?
      services.first.action
    end

    # Current start mode in the system
    #
    # @note It offers an additional state `:inconsistent` that is not in {Yast2::SystemService}
    #
    # @see Yast2::SystemService#current_start_mode
    #
    # @return [:on_boot, :on_demand, :manual, :inconsistent]
    #
    #   - `:on_boot`      all services start during boot.
    #
    #   - `:on_demand`    all sockets associated with services are enabled and
    #                     for services that do not have socket, they start on boot.
    #
    #   - `:manual`       all services and all their associated sockets are disabled.
    #
    #   - `:inconsistent` mixture of start modes
    def current_start_mode
      @current_start_mode ||= services_mode(method(:current_mode?))
    end

    # Target start mode
    #
    # @note It offers and additional start mode `:inconsistent` that is not in {Yast2::SystemService}
    #
    # @see Yast2::SystemService#start_mode
    #
    # @return [:on_boot, :on_demand, :manual, :inconsistent]
    #
    #   - `:on_boot`      when start mode is set to :on_boot for all services.
    #
    #   - `:on_demand`    when start mode is set to :on_demand for services that
    #                     support it and :on_boot for the rest.
    #
    #   - `:manual`       when start mode is set to :manual for all services.
    #
    #   - `:inconsistent` when services have mixture of start modes
    def start_mode
      services_mode(method(:mode?))
    end

    AUTOSTART_OPTIONS = [:on_boot, :on_demand, :manual, :inconsistent].freeze

    # Sets the target start mode
    #
    # @note It offers and additional start mode `:inconsistent` that is not in {Yast2::SystemService}
    #
    # @param configuration [Symbol] new start mode (e.g., :on_boot, :on_demand, :manual, :inconsistent)
    def start_mode=(configuration)
      if !AUTOSTART_OPTIONS.include?(configuration)
        raise ArgumentError, "Invalid parameter #{configuration.inspect}"
      end

      if configuration == :inconsistent
        reset(exclude: [:action])
      elsif configuration == :on_demand
        services_with_socket.each { |s| s.start_mode = :on_demand }
        services_without_socket.each { |s| s.start_mode = :on_boot }
      else
        services.each { |s| s.start_mode = configuration }
      end
    end

    # Whether any service allows to start on demand
    #
    # @see Yast2::SystemService#support_start_on_demand?
    #
    # @return [Boolean]
    def support_start_on_demand?
      services.any?(&:support_start_on_demand?)
    end

    # Whether the service supports :on_boot start mode
    #
    # @see Yast2::SystemService#support_start_on_boot?
    #
    # @return [Boolean]
    def support_start_on_boot?
      services.any?(&:support_start_on_boot?)
    end

    # Errors when trying to write changes to the underlying system
    #
    # @see Yast2::SystemService#errors
    #
    # @return [Hash<Symbol, Object>]
    def errors
      services.each_with_object({}) do |s, result|
        result.merge!(s.errors)
      end
    end

    # Resets changes
    #
    # @see Yast2::SystemService#reset
    #
    # @param exclude [Array] to exclude from reset some parts.
    #   Now supported: `:action` and `:start_mode`
    def reset(exclude: [])
      old_action = action
      old_start_mode = start_mode
      services.each(&:reset)
      @current_start_mode = nil
      public_send(old_action) if !old_action.nil? && exclude.include?(:action)
      self.start_mode = old_start_mode if old_start_mode != :inconsistent && exclude.include?(:start_mode)
    end

    # Sets all services to be started after calling {#save}
    #
    # @see Yast2::SystemService#start
    def start
      services.each(&:start)
    end

    # Sets all services to be stopped after calling {#save}
    #
    # @see Yast2::SystemService#stop
    def stop
      services.each(&:stop)
    end

    # Sets all services to be restarted after calling {#save}
    #
    # @see Yast2::SystemService#restart
    def restart
      services.each(&:restart)
    end

    # Sets all services to be reloaded after calling {#save}
    #
    # @see Yast2::SystemService#reload
    def reload
      services.each(&:reload)
    end

  private

    def current_mode?(start_mode)
      ->(service) { service.current_start_mode == start_mode }
    end

    def mode?(start_mode)
      ->(service) { service.start_mode == start_mode }
    end

    def services_mode(mode_method)
      if services.all?(&mode_method.call(:on_boot))
        :on_boot
      elsif services.all?(&mode_method.call(:manual))
        :manual
      elsif services_with_socket.all?(&mode_method.call(:on_demand)) &&
          services_without_socket.all?(&mode_method.call(:on_boot))
        :on_demand
      else
        :inconsistent
      end
    end

    def services_with_socket
      @services_with_socket ||= services.select(&:support_start_on_demand?)
    end

    def services_without_socket
      @services_without_socket ||= services.reject(&:support_start_on_demand?)
    end
  end
end
