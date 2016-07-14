require "yast"

module Installation
  # An abstract class that simplifies writing `*_auto.rb` clients for AutoYaST.
  #
  # It provides a single entry point
  # which dispatches calls to the abstract methods that all proposal clients
  # need to implement.
  #
  # You need to implement all the methods, except {#packages}.
  #
  # "Autoinstall" basically means {#import}, then {#write}.
  #
  # "Clone" means {#read}, then {#export}.
  #
  # The workflow for interactive editing in the UI
  # (`Mode.config == true`, see {Yast::ModeClass})
  # is more complicated. The user can choose to perform any action, and
  # a corresponding method is called:
  #
  # - {#summary}: clicking on the icon of the module.
  # - {#reset}: clicking Clear.
  # - if the user clicks to Edit a module, at first {#export} is called,
  #   then {#change} is called for UI interaction, which can end up
  #   in multiple situations:
  #   - if cancelled/aborted, {#import} is called (on the previous result of
  #     {#export})
  #   - otherwise {#export} is called. If the output is different from the
  #     previous call, then {#modified} is called.
  # - {#write}: clicking Apply to System.
  # - {#read}: clicking Clone.
  # - {#import}: selecting File/Open to load an autoyast profile
  # - it calls {#modified?} to recognize if a given module is modified and needs
  #   its section with content of {#export} when saving the profile
  # - the order of all calls is independent, so the client should not depend
  #   on a certain order unless it is defined here as a workflow call
  #
  #
  # @example how to run a client
  #   require "installation/example_auto"
  #   ::Installation::ExampleAuto.run
  #
  # @see https://github.com/yast/yast-bootloader/blob/master/src/clients/bootloader_auto.rb
  #   Example client, bootloader_auto.rb
  # @see http://users.suse.com/~ug/autoyast_doc/devel/ar01s05.html
  #   Code-related configuration and some old documenation.
  class AutoClient < Yast::Client
    include Yast::Logger

    # Entry point for calling the client.
    # The only part needed in client rb file.
    # @return response from abstract methods
    def self.run
      new.run
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
        raise ArgumentError, "Invalid action for auto client '#{func.inspect}'"
      end
    end

  protected

    # Import data from AutoYaST profile.
    #
    # The profile is a Hash or an Array according to the configuration item
    # `X-SuSE-YaST-AutoInstDataType`
    # @param profile [Hash, Array] profile data specific to this module.
    # @return true on success
    def import(_profile)
      raise NotImplementedError, "Calling abstract method 'import'"
    end

    # Export profile data from AutoYaST.
    #
    # The profile is a Hash or an Array according to the configuration item
    # `X-SuSE-YaST-AutoInstDataType`
    # @return [Hash, Array] profile data
    def export
      raise NotImplementedError, "Calling abstract method 'export'"
    end

    # Provide a brief summary of configuration.
    # @return [String] description in RichText format
    def summary
      raise NotImplementedError, "Calling abstract method 'summary'"
    end

    # Reset configuration to default state.
    # @return [void]
    def reset
      raise NotImplementedError, "Calling abstract method 'reset'"
    end

    # Run UI to modify the  configuration.
    # @return [Symbol] If one of `:accept`, `:next`, `:finish` is returned,
    #   the changes are accepted, otherwise they are discarded.
    def change
      raise NotImplementedError, "Calling abstract method 'change'"
    end

    # Write settings to the target system.
    # @return [Boolean] true on success
    def write
      raise NotImplementedError, "Calling abstract method 'write'"
    end

    # Get a list of packages needed for configuration.
    #
    # The default implementation returns an empty list.
    # @return [Array<String>] list of required packages
    def packages
      log.info "#{self.class}#packages not implemented, returning []."

      []
    end

    # Read settings from the target system.
    #
    # It is used to initialize configuration from the current system
    # for further represent in AutoYaST profile.
    # @return [void]
    def read
      raise NotImplementedError, "Calling abstract method 'write'"
    end

    # Set that the profile data has beed modified
    # and should be exported from the interactive editor,
    # or included in the cloned data.
    # @return [void]
    def modified
      raise NotImplementedError, "Calling abstract method 'modified'"
    end

    # Query whether the profile data has beed modified
    # and should be exported from the interactive editor,
    # or included in the cloned data.
    # @return [Boolean]
    def modified?
      raise NotImplementedError, "Calling abstract method 'modified?'"
    end
  end
end
