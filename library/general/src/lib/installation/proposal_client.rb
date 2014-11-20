require "yast"

module Installation
  # Abstract class that simplify writting proposal clients for installation.
  # It provides single entry point and abstract methods, that all proposal clients
  # need to implement.
  # @example how to run client
  #   require "installation/example_proposal"
  #   ::Installation::ExampleProposal.run
  # @see for example client in installation clone_proposal.rb
  # @see proposal_api_reference to get overview of proposal client API
  class ProposalClient < Yast::Client
    include Yast::Logger

    # Entry point for calling client. Only part needed in client rb file.
    # @return response from abstract methods
    def self.run
      self.new.run
    end

    # Dispatches to abstract method based on passed Arguments to client
    def run
      func, param = Yast::WFM.Args
      case func
      when "MakeProposal"
        make_proposal(param)
      when "AskUser"
        ask_user(param)
      when "Description"
        description
      when "Write"
        write(param)
      else
        raise "Invalid action for proposal '#{func.inspect}'"
      end
    end

  protected

    # Abstract method to create proposal suggestion
    # @param [Map<String,Object>] attrs. Currently passed keys are "force_reset"
    #   which indicate that user preference should be thrown away and
    #   "language_changed" that indicate that language is changed, so cache with
    #   text should be renew.
    # @return [Map] with proposal attributes. Expected keys are "help" for
    #   client specific help, "preformatted_proposal" for richtext formatted
    #   proposal result, "links" with list of anchors used in proposal text.
    #   Optional keys are "warning_level" and "warning" used for showing warnings.
    def make_proposal(attrs)
      raise NotImplementedError, "Calling abstract method 'make_proposal'"
    end

    # Abstract method to react on user action
    # @param [Map<String,Object>] attrs. Currently passed key is "chosen_id"
    #   where is specified action user made. It can be anything from links passed
    #   in make_proposal or it can be click on tittle, in which case id from
    #   description is passed.
    # @return [Map] with key "workflow_sequence" which specify what should happen.
    #   Possible values are :next if everything is correct, :back if user requested
    #   to go back, :again if client should be called again, :auto if it depends on
    #   previous client response and :finish if to finish installation.
    #   Optional key is "language_changed" if module changed installation language.
    def ask_user(attrs)
      raise NotImplementedError, "Calling abstract method 'ask_user'"
    end

    # Abstract method to return human readable titles both for the RichText
    # (HTML) widget and for menuentries. Also specify id which is used when
    # user select module.
    # @return [Map] with keys "rich_text_title", "menu_title" and "id".
    def description
      raise NotImplementedError, "Calling abstract method 'description'"
    end

    # Optional abstract method to write settings.
    # @return true if succeed
    def write(attrs)
      log.error "Write called, but proposal do not implement it"

      nil
    end
  end
end
