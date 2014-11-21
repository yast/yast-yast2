require "yast"

module Installation
  # Abstract class that simplify writting auto clients for autoyast.
  # It provides single entry point and abstract methods, that all proposal clients
  # need to implement.
  # @example how to run client
  #   require "installation/example_auto"
  #   ::Installation::ExampleAuto.run
  #
  # @see for example client in installation bootloader_auto.rb
  # @see http://users.suse.com/~ug/autoyast_doc/devel/ar01s05.html for configuration and some old documenation
  class AutoClient < Yast::Client
    include Yast::Logger

    # Entry point for calling client. Only part needed in client rb file.
    # @return response from abstract methods
    def self.run
      self.new.run
    end

    # Dispatches to abstract method based on passed Arguments to client
    def run
      func, param = Yast::WFM.Args
      log.info "Called #{self.class}.run with #{func} and params #{param}"

      case func
      when "Import"
        import(param)
      when "Export"
        export
      when "Summary"
        summary
      when "Reset"
        reset
      when "Change"
        change
      when "Write"
        write
      when "Packages"
        packages
      when "Read"
        read
      when "GetModified"
        modified?
      when "SetModified"
        modified
      else
        raise "Invalid action for auto client '#{func.inspect}'"
      end
    end

  protected

    # Abstract method to import data from autoyast profile
    # @param [Map] data from autoyast
    # @return true if succeed
    def import(data)
      raise NotImplementedError, "Calling abstract method 'import'"
    end

    # Abstract method to return configuration map for autoyast
    # @return [Map] autoyast data
    def export
      raise NotImplementedError, "Calling abstract method 'export'"
    end

    # Abstract method to provide brief summary of configuration.
    # @return [String] description in richtext format
    def summary
      raise NotImplementedError, "Calling abstract method 'summary'"
    end

    # Abstract method to reset configuration to default state.
    # @return [Map] returns empty map or default values. TODO it looks like it doesn't matter
    def reset
      raise NotImplementedError, "Calling abstract method 'reset'"
    end

    # Abstract method to start widget sequence to modify configuration
    # @return [Symbol] returns sequence symbol from widget
    def change
      raise NotImplementedError, "Calling abstract method 'change'"
    end


    # Abstract method to write settings to target.
    # @return true if succeed
    def write
      raise NotImplementedError, "Calling abstract method 'write'"
    end

    # Optional abstract method to get list of methods needed for configuration.
    # Default implementation return empty list
    # @return [Array<String>] list of required packages
    def packages
      log.info "#{self.class} do not implement packages, return default."

      []
    end

    # Abstract method to read settings from target. It is used to initialize configuration
    # from current system for further represent in autoyast profile.
    # @return ignored
    def read
      raise NotImplementedError, "Calling abstract method 'write'"
    end

    # Abstract method to set flag for configuration that it is modified by autoyast.
    def modified
      raise NotImplementedError, "Calling abstract method 'modified'"
    end

    # Abstract method to query if configuration is modified and should be written.
    def modified?
      raise NotImplementedError, "Calling abstract method 'modified?'"
    end

  end
end
