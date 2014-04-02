require 'yast2/systemd_unit'

module Yast

  ###
  # Systemd.target unit control API
  # @example How to find a custom systemd target
  #
  #   require 'yast'
  #
  #   Yast.import 'SystemdTarget'
  #
  #   # This will return either a target object or nil
  #   target = Yast::SystemdTarget.find('graphical')
  #
  #   # This returns target object or raises exception SystemdTargetNotFound
  #   target = Yast::SystemdTarget.find!('whatever')
  #
  #   # This returns collection of all available targets
  #   Yast::SystemdTarget.all
  #
  # @example How to find the current default target
  #
  #   target = Yast::SystemdTarget.get_default
  #   target.unit_name      # name of the default target
  #   target.allow_isolate? # should return true
  #
  # @example Set the default target
  #
  #   Yast::SystemdTarget.set_default('multi-user') # returns true if success
  #
  #   # Or if we have already an target object, use this for default target
  #   target = Yast::SystemdTarget.find('graphical')
  #   target.allow_isolate? # must be true to set default target
  #   target.set_default # returns true if success
  ###

  class SystemdTargetNotFound < StandardError
    def initialize target_name
      super "Target unit '#{target_name}' not found"
    end
  end

  class SystemdTargetClass < Module
    UNIT_SUFFIX    = ".target"
    DEFAULT_TARGET = "default.target"
    PROPERTIES     = { :allow_isolate => "AllowIsolate" }

    def find target_name, properties={}
      target_name += UNIT_SUFFIX unless target_name.end_with?(UNIT_SUFFIX)
      target = Target.new(target_name, PROPERTIES.merge(properties))
      return nil if target.properties.not_found?
      target
    end

    def find! target_name, properties={}
      find(target_name) || raise(SystemdTargetNotFound, target_name)
    end

    def all properties={}
      Systemctl.target_units.map do |target_unit_name|
        find(target_unit_name)
      end
    end

    def get_default
      result = Systemctl.execute("get-default")
      raise(SystemctlError, result) unless result.exit.zero?

      find(result.stdout.strip)
    end

    def set_default target
      target_unit = target.is_a?(Target) ? target : find(target)
      return false unless target_unit
      target_unit.set_default
    end

    class Target < SystemdUnit

      # Disable unsupported methods for target units
      undef_method :start, :stop, :enable, :disable, :restart

      def allow_isolate?
        properties.allow_isolate == 'yes'
      end

      def set_default
        return false unless allow_isolate?

        result = Systemctl.execute("set-default --force " << id)
        result.exit.zero?
      end
    end
  end
  SystemdTarget = SystemdTargetClass.new
end
