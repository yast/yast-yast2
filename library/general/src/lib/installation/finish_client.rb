require "yast"

module Installation
  # Abstract class that simplify writting finish clients for installation.
  # It provides single entry point and abstract methods, that all finish clients
  # need to implement.
  # @example how to run client
  #   require "installation/example_finish"
  #   ::Installation::ExampleFinish.run
  # @see for example client in installation clone_finish.rb
  #
  # # Inst-Finish Scripts
  # ## About
  # They are called by the inst_finish.ycp installation client at the end of the
  # first stage installation.
  #
  # Part of these clients are called with SCR connected to inst-sys, the others
  # are called after SCR gets switched to the installed system (chrooted).
  #
  # Script inst_finish.ycp contains several stages, every has
  #
  #   * label - visible in the writing progress
  #
  #   * steps - list of additional inst_finish scripts that are called
  #   ("bingo" -> "bingo_finish.ycp")
  #   Important script is "switch_scr", after that call, SCR is connected to the
  #   just installed system.
  #
  # ## Finish Scripts
  #
  # Every single finish script is a non-interactive script (write-only). It's
  # basically called twice:
  #
  #   * At first "Info" returns in which modes "Write" should be called
  #
  #   * Then "Write" should be called to do the job
  #
  class FinishClient < Yast::Client
    include Yast::Logger

    # Entry point for calling client. Only part needed in client rb file.
    # @return response from abstract methods
    def self.run
      self.new.run
    end

    # Dispatches to abstract method based on passed arguments to client
    def run
      func = Yast::WFM.Args.first
      log.info "Called #{self.class}.run with #{func}"

      case func
      when "Info"
        info
      when "Write"
        write
      else
        raise ArgumentError, "Invalid action for proposal '#{func.inspect}'"
      end
    end

  protected

    # Abstract method to write configuration
    def write
      raise NotImplementedError, "Calling abstract method 'write'"
    end

    # Abstract method to provide information about client
    # @return [Map] with keys "steps" which specify number of client steps,
    #   "when" with list of symbols for modes when client make sense, if missing,
    #   then run always. And last but not least is tittle which is used to display
    #   to user what happening.
    def info
      raise NotImplementedError, "Calling abstract method 'info'"
    end
  end
end
