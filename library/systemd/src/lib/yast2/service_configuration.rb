require "yast"

Yast.import "SystemdService"

module Yast2
  # Class that holds configuration for single or multiple services. It allows
  # read current status from system. It allows to modify target state. And it
  # allows to write that target state so system reflects it.
  # Its common usage is with {Yast2::ServiceWidget} which allows to modify
  # configuration and write it when user approve whole dialog.
  class ServiceConfiguration
    include Yast::Logger

    # services managed by this configuration
    attr_reader :services

    # creates new configuration that holds state for given services
    # @param services<Yast::SystemdServiceClass::Service> services to configure
    # @param reload<true,false> if use reload instead of restart action. If
    #   service does not support reload or does not run, then restart is used.
    #
    # @example three services that wants reload instead of restart
    #   config = Yast2::ServiceConfiguration.new(s1, s2, s3, reload: true)
    def initialize(*services, reload: false)
      if services.any? { |s| !s.is_a?(Yast::SystemdServiceClass::Service) }
        raise ArgumentError, "Services can be only Systemd Service - #{services.inspect}"
      end

      @services = services
      @reload = reload
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
    #   - `:stop`  to stop all services. If service already is inactive, do nothing.
    #   - `:restart` restart all services. Can be reload if specified during
    #       construction of this class. If service is inactive, it is started.
    #   - `:nothing` do not touch anything.
    def action
      return :nothing unless @action

      @action
    end

    # sets target action for services
    # @param action[:start, :stop, :restart, :nothing] for possible values and
    #  its explanation please see return value of {target_action}
    def action= (action)
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

    # sets autostart configuration.
    # @param [:on_boot, :on_demand, :manual, :inconsistent] autostart
    # configuratio. For explanation please see {target_autostart} when
    # `:inconsistent` means keep it as it is now.
    def autostart=(configuration)
    end

  private

    def read_status
      services_active = @services.map { |s| s.active? }

      return @status = :active if services_active.all?
      return @status = :inactive if services_active.none?
      @status = :inconsistent
    rescue Yast::SystemctlError => e
      log.error "systemctl failure: #{e.inspect}"
      @status = :unknown
    end

    def read_autostart
    end
  end
end
