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
  # It mimics behavior of single SystemService, just adds additional possible states.
  class CompoundService
    include Yast::Logger

    # managed services
    # @return [Array<Yast2::SystemService>]
    attr_reader :services

    # creates new configuration that holds state for given services
    # @param services [Array<Yast::SystemService>] services to configure
    #
    # @example three services
    #   service = Yast2::CompountService.new(s1, s2, s3)
    def initialize(*services)
      if services.any? { |s| !s.is_a?(Yast2::SystemService) }
        raise ArgumentError, "Services can be only System Service - #{services.inspect}"
      end

      @services = services
    end

    # writes services new status
    # @raise <Yast::SystemctlError> when set service to target state failed
    def save(keep_state: false)
      services.each { |s| s.save(keep_state: keep_state) }
    end

    # returns current running status.
    # @return [true, false, :inconsistent] current status of
    #   services:
    #
    #   - `true` when all services are active
    #   - `false` when all services are inactive
    #   - `:inconsistent` when part of services is active and part not.
    def current_active?
      return true if services.all?(&:current_active?)
      return false if services.none?(&:current_active?)
      :inconsistent
    end

    # returns true if any service supports reload
    def support_reload?
      services.any?(&:support_reload?)
    end

    def start_modes
      @start_modes ||= services.map(&:start_modes).reduce(:+).uniq
    end

    def keywords
      services.map(&:keywords).reduce(:+).uniq
    end

    # returns currently set target action. If it is not yet set it returns
    # `:nothing`.
    # @return [:start, :stop, :restart, :nothing] action for all services:
    #
    #   - `:start` to start all services. If service is already active, do nothing.
    #     if services has socket it starts socket instead of service.
    #   - `:stop`  to stop all services. If service already is inactive, do nothing.
    #   - `:restart` restart all services. If service is inactive, it is started.
    #   - `:reload` reload all services that support it and restart that does not
    #       support it. If service is inactive, it is started.
    #   - `nil` do not touch anything.
    def action
      # TODO: check for inconsistencies?
      services.first.action
    end

    # returns current system start mode.
    # @return [:on_boot, :on_demand, :manual, :inconsistent] start_mode configuration:
    #
    #   - `:on_boot` all services start during boot.
    #   - `:on_demand`  all sockets associated with services is enabled and
    #     for services that does not have socket, it starts on boot.
    #   - `:manual` all services and all its associated sockets is disabled.
    #   - `:inconsistent` mixture of states
    # @see Yast::SystemService#current_start_mode
    # @note additional state `:inconsistent` that is not in SystemService
    def current_start_mode
      @current_start_mode ||= services_mode(method(:has_current_mode))
    end

    # returns configuration for start mode.
    # @return [:on_boot, :on_demand, :manual, :inconsistent] start_mode configuration:
    #
    #   - `:on_boot` when start mode is set to on_boot for all services.
    #   - `:on_demand` when start mode is set to on_demand for services that support it and on_boot
    #     otherwise.
    #   - `:manual` when start mode is set to manual for all services.
    #   - `:inconsistent` when services have mixture of start modes
    # @see Yast::SystemService#start_mode
    # @note additional state `:inconsistent` that is not in SystemService
    def start_mode
      services_mode(method(:has_mode))
    end

    AUTOSTART_OPTIONS = [:on_boot, :on_demand, :manual, :inconsistent].freeze
    # sets start mode configuration.
    # @param [:on_boot, :on_demand, :manual, :inconsistent] sets start_mode.
    #   See {Yast2::SystemService.start_mode=}. Additionally inconsistent is used
    #   to keep current start mode. For each service.
    def start_mode=(configuration)
      if !AUTOSTART_OPTIONS.include?(configuration)
        raise ArgumentError, "Invalid parameter #{configuration.inspect}"
      end

      if configuration == :inconsistent
        reset(exclude: [:action])
      else
        services.all { |s| s.start_mode = configuration }
      end
    end

    # returns true if any allow start on demand
    def support_start_on_demand?
      @services.any?(&:support_start_on_demand?)
    end

    # resets changes.
    # @param exclude [Array] exclude from reset some parts. Now supported: `:action` and
    #   `:start_mode`.
    def reset(exclude: [])
      old_action = action
      old_start_mode = start_mode
      services.all(&:reset)
      @current_start_mode = nil
      public_send(old_action) if old_action != nil && !exclude.include?(:action)
      if old_start_mode != :inconsistent && !exclude.include?(:start_mode)
        self.start_mode = old_start_mode
      end
    end

    def start
      services.each(&:start)
    end

    def stop
      services.each(&:stop)
    end

    def restart
      services.each(&:restart)
    end

    def reload
      services.each(&:reload)
    end

  private

    def has_current_mode(start_mode)
      ->(service) { service.current_start_mode == start_mode }
    end

    def has_mode(start_mode)
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
      @services_with_socket ||= services.select{ |s| s.support_start_on_demand? }
    end

    def services_without_socket
      @services_without_socket ||= services.reject{ |s| s.support_start_on_demand? }
    end
  end
end
