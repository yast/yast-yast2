require "yast"
require "yast2/systemd_service"

module Yast2
  # Class that holds configuration for single or multiple services. It allows
  # to read current status from system. It allows to modify target state. And it
  # allows to write that target state so system reflects it.
  # Its common usage is with {Yast2::ServiceWidget} which allows to modify
  # configuration and write it when user approve whole dialog.
  class ServiceConfiguration
    include Yast::Logger

    # services managed by this configuration
    attr_reader :services

    # creates new configuration that holds state for given services
    # @param services<Yast::SystemdService> services to configure
    # @param reload<true,false> if use reload instead of restart action. If
    #   service does not support reload or does not run, then restart is used.
    #
    # @example three services
    #   config = Yast2::ServiceConfiguration.new(s1, s2, s3)
    def initialize(*services)
      if services.any? { |s| !s.is_a?(Yast::SystemdService) }
        raise ArgumentError, "Services can be only Systemd Service - #{services.inspect}"
      end

      @services = services
    end

    # reads system status of services. Can be also used to reread current status.
    # @raise <Yast::SystemctlError> when read services state failed
    def read
      # safe initial state when exception happen
      @status = :unknown
      @autostart = :unknown

      read_status
      read_autostart
    end

    # writes services new status
    # @raise <Yast::SystemctlError> when set service to target state failed
    def write
      write_action
      write_autostart
    end

    # returns current running status, but when read failed return `:unknown`.
    # @return [:active, :inactive, :inconsistent, :unknown] current status of
    #   services:
    #
    #   - `:active` when all services are active
    #   - `:inactive` when all services are inactive
    #   - `:inconsistent` when part of services is active and part not.
    #       Can happen only when configuration handle multiple services
    #   - `:unknown` when read of current status failed.
    def status
      read unless @status

      @status
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
    #   - `:nothing` do not touch anything.
    def action
      return :nothing unless @action

      @action
    end

    ACTIONS = [:start, :stop, :reload, :restart, :nothing].freeze
    # sets target action for services
    # @param action[:start, :stop, :restart, :reload, :nothing] for possible values and
    #  its explanation please see return value of {target_action}
    def action=(action)
      if !ACTIONS.include?(action)
        raise ArgumentError, "Invalid parameter #{action.inspect}"
      end

      @action = action
    end

    # returns currently set autostart configuration. If it is not yet set it
    # calls read and return current system state.
    # @return [:on_boot, :on_demand, :manual, :inconsistent, :unknown] autostart
    #   configuration:
    #
    #   - `:on_boot` all services start during boot.
    #   - `:on_demand`  all sockets associated with services is enabled and
    #     for services that does not have socket, it starts on boot.
    #   - `:manual` all services and all its associated sockets is disabled.
    #   - `:inconsistent` mixture of states
    #   - `:unknown` when no state is set and read call failed.
    def autostart
      read unless @autostart

      @autostart
    end

    AUTOSTART_OPTIONS = [:on_boot, :on_demand, :manual, :inconsistent].freeze
    # sets autostart configuration.
    # @param [:on_boot, :on_demand, :manual, :inconsistent] autostart
    # configuratio. For explanation please see {autostart} when
    # `:inconsistent` means keep it as it is now.
    def autostart=(configuration)
      if !AUTOSTART_OPTIONS.include?(configuration)
        raise ArgumentError, "Invalid parameter #{configuration.inspect}"
      end

      @autostart = configuration
    end

    # returns true if any service support reload
    def support_reload?
      # TODO: implement it
      true
    end

    # returns true if any service has socket start
    def support_on_demand?
      @services.any?(&:socket?)
    end

  private

    def read_status
      services_active = @services.map(&:active?)

      return @status = :active if services_active.all?
      return @status = :inactive if services_active.none?
      @status = :inconsistent
    rescue Yast::SystemctlError => e
      log.error "systemctl failure: #{e.inspect}"
      @status = :unknown
    end

    def read_autostart
      sockets = @services.map(&:socket).compact
      services_without_socket = @services.reject(&:socket)
      @autostart = if sockets.all?(&:enabled?) && services_without_socket.all?(&:enabled?)
        :on_demand
      elsif @services.all?(&:enabled?)
        :on_boot
      elsif sockets.none?(&:enabled?) && @services.none?(&:enabled?)
        :manual
      else
        :inconsistent
      end
    rescue Yast::SystemctlError => e
      log.error "systemctl failure: #{e.inspect}"
      @autostart = :unknown
    end

    def write_autostart
      case autostart
      when :on_boot then @services.each { |s| s.start_mode = :boot }
      when :on_demand
        @services.each do |service|
          service.start_mode = if service.start_modes.include?(:demand)
            :demand
          else
            :boot
          end
        end
      when :manual then @services.each { |s| s.start_mode = :manual }
      when :inconsistent then log.info "keeping current autostart"
      else
        raise "Unexpected action #{autostart.inspect}"
      end
    end

    def write_action
      case action
      when :start
        sockets = @services.map(&:socket).compact
        services_without_socket = @services.reject(&:socket)
        sockets.each(&:start)
        services_without_socket.each(&:start)
      when :stop then @services.each(&:stop)
      when :reload then @services.each(&:reload_or_restart)
      when :restart then @services.each(&:restart)
      when :nothing then log.info "no action"
      else
        raise "Unexpected action #{action.inspect}"
      end
    end
  end
end
