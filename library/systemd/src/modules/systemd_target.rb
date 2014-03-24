require 'yast2/systemd_unit'

module Yast
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
      target_name << UNIT_SUFFIX unless target_name.end_with?(UNIT_SUFFIX)
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
      undef_method :start, :stop, :enable, :disable

      def allow_isolate?
        properties.allow_isolate == 'yes'
      end

      def set_default
        return false unless allow_isolate?

        result = Systemctl.execute("set-default --force " << self.id)
        result.exit.zero?
      end
    end
  end
  SystemdTarget = SystemdTargetClass.new
end
