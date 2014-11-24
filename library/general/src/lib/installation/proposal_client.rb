require "yast"

module Installation
  # Abstract class that simplify writting proposal clients for installation.
  # It provides single entry point and abstract methods, that all proposal clients
  # need to implement.
  # @example how to run client
  #   require "installation/example_proposal"
  #   ::Installation::ExampleProposal.run
  # @see for example client in installation clone_proposal.rb
  #
  #
  # # API for YaST2 installation proposal
  # ## Motivation
  # After five releases, YaST2 is now smart enough to make reasonable proposals for
  # (near) every installation setting, thus it is no longer necessary to ask the
  # user that many questions during installation: Most users simply hit the [next]
  # button anyway.
  #
  # Hence, YaST2 now collects all the individual proposals from its submodules and
  # presents them for confirmation right away. The user can change each individual
  # setting, but he is no longer required to go through all the steps just to
  # change some simple things. The only that (currently) really has to be queried
  # is the installation language - this cannot reasonably be guessed (yet?).
  #
  # ## Overview
  # YaST2 installation modules should cooperate with the main program in a consistent API. General usage:
  #
  # * inst_proposal (main program) creates empty dialog with RichText widget
  #
  # * inst_proposal calls each sub-module in turn to make proposal
  #
  # * user may choose to change individual settings (i.e., clicks on a hyperlink)
  #
  # * inst_proposal starts that module's sub-workflow which runs independently.
  #   After this, inst_proposal tells all subsequent (all?) modules to check their
  #   states and return whether a change of their proposal is necessary after the
  #   user interaction.
  #
  # * main program calls each sub-module to write the settings to the system
  #
  # ## API functions
  # If any parameter is marked as "optional", it should only be specified if
  # it contains a meaningful value. Do not add it with a `nil` value.
  #
  # It is recommended to use Installation::ProposalClient as base class for new clients.
  # This base class, implemented in yast2-yast, provides automatic method dispatching.
  #
  # ### MakeProposal
  # Makes proposal for installation.
  #
  # #### Parameters
  #
  # * _boolean_ `force_reset` If `true`, discard anything that may be cached and
  #   start over from scratch. If `false`, use cached values from the last
  #   invocation if there are any.
  #
  # * _boolean_ `language_changed` The installation language has changed since the last call of
  #   `MakeProposal`. This is important only if there is a language change mechanism in one of the other submodules.
  #   If this parameter is "true", any texts the user can see in
  #   the proposal need to be retranslated. The internal translator mechanism
  #   will take care of this itself if the corresponding strings are once more
  #   put through it (the `_("...")` function). Only very few
  #   submodules that translate any strings internally based on internal maps
  #   (e.g., keyboard etc.) need to take more action.
  #
  # #### Return Values
  # `MakeProposal()` returns a map containing:
  # * _list\<string\>_ `links` A list of additional hyperlink ids used in summaries returned by this
  #       section. All possible values must be included.
  #
  # * _string_ `preformatted_proposal` (optional) Human readable proposal preformatted in HTML. It is possible to use the HTML:: module for such formatting.
  #
  # * _list_ `raw_proposal` (only used if 'preformatted_proposal' is not present in the result map). Human readable proposal, not formatted yet. The caller will format each
  #       list item (string) as a HTML list item `( "<li> ... </li>" )`. The proposal can contain hyperlinks with ids listed in the list `links`.
  # * _string_ `warning` (optional) Warning in human readable format without HTML tags other than `<br>`. The warning will be embedded in appropriate HTML format specifications
  #       according to 'warning_level' below.
  #
  # * _symbol_ `warning_level` (optional) Determines the severity and the visual display of the warning.
  #   Valid values:
  #
  #   * `:notice`
  #   * `:warning (default)`
  #   * `:error`
  #   * `:blocker`
  #   * `:fatal`
  #
  #   _:blocker_ will prevent the user from continuing the installation. If any proposal contains a `:blocker` warning, the "accept"
  #   button in the proposal dialog will be disabled - the user needs to fix that blocker before continuing.
  #
  #   _:fatal_ is like `blocker but also stops building the proposal
  #
  # * _boolean_ `language_changed` This module just caused a change of the installation language. This is only relevant for the "language" module.
  # * _boolean_ `mode_changed` (optional) This module just caused a change of the installation mode. This is only
  #   relevant for the "inst mode" module.
  #
  # * _boolean_ `rootpart_changed` (optional) This module just caused a change of the root partition. This is only
  #   relevant for the "root part" module.
  #
  # * _string_ `help` (optional) Helptext for this module which appears in the standard dialog
  #   help (particular helps for modules sorted by presentation order).
  #
  # ### AskUser
  # Run an interactive workflow - let user decide upon values he might want to change.
  # May contain one single dialog, a sequence of dialogs or one master dialog with
  # one or more "expert" dialogs. It can be also non-interactive click on hyperlink.
  # The module is responsible for controlling the workflow sequence (i.e., "next",
  # "back" buttons etc.).
  #
  # Submodules do not provide an "abort" button to abort the entire installation. If
  # the user wishes to do that, he can always go back to the main dialog (the
  # installation proposal) and choose "abort" there.
  #
  # #### Parameters
  #
  # * _boolean_ `has_next` Use a "next" button even if the module by itself has only one step, thus
  #   would normally have an "OK" button - or would rename the "next" button to something like "finish" or "accept".
  #
  # * _string_ `chosen_id` If a section proposal contains hyperlinks and user clicks on one of them,
  #   this defines the id of the hyperlink. All hyperlink IDs must be set in the map retuned by `Description`. If a user did not click
  #   on a proposal hyperlink, this parameter is not defined.
  #
  # #### Return Values
  # `AskUser()` returns a map containing:
  #
  # * _symbol_ workflow_sequence with possible values:
  #
  #   * `:next` (default) Everything OK - continue with the next step in workflow sequence.
  #
  #   * `:back` User requested to go back in the workflow sequence.
  #
  #   * `:again` Call this submodule again (i.e., re-initialize the submodule)
  #
  #   * `:auto` Continue with the workflow sequence in the current direction
  #     - forward if the last submodule returned `next, backward otherwise.
  #
  #   * `:finish` Finish the installation. This is specific to "inst_mode.ycp" when
  #     the user selected "boot system" there.
  #
  # * _boolean_ language_changed (optional) This module just caused a change of the installation language. This is
  #   only relevant for the "language" module.
  #
  # ### Description
  # Return human readable titles both for the RichText (HTML) widget and for menuentries.
  #
  # #### Return Values
  # Returns a map containing:
  #
  # * _string_ `rich_text_title` (Translated) human readable title for this section in
  #   the `RichText` widget without any HTML formatting. This will be embedded in
  #   `<h3><a href="#???"> ... </a></h3>` so make sure not to add any additional HTML formatting.
  #   Keyboard shortcuts are not (yet?) supported, so do not include any `&` characters.
  #
  # * _string_ `menu_title` (Translated) human readable menuentry for this section. Must contain
  #   a keyboard shortcut ('&'). Should NOT contain trailing periods ('...') - the caller will add them.
  #
  # * _string_ `id` Programmer readable unique identifier for this section. This is not
  #   auto-generated to keep the log file readable.
  #
  #
  # This map may be empty. In this case, this proposal section will silently
  # be ignored. Proposals modules may use this if there is no useful proposal
  # at all. Use with caution - this may be confusing for the user.
  #
  # In this case, all other proposal functions must return a useful success
  # value so they can be called without problems.
  #
  # ### Write
  # Write the proposed (and probably modified) settings to the system.
  # It is up to the proposal dispatcher how it remembers the settings.
  # The errors must be reported using the Report:: module to have
  # the possibility to control the behaviour from the main program.
  #
  # This Write() function is optional. The dispatcher module is required
  #     to allow this function to be called without returning an error value
  #     if it is not there.
  #
  # #### Return Values
  # Returns true, if the settings were written successfully.
  #
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
      log.info "Called #{self.class}.run with #{func} and params #{param}"

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
    # @see MakeProposal API method
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
    # @see AskUser API method
    def ask_user(attrs)
      raise NotImplementedError, "Calling abstract method 'ask_user'"
    end

    # Abstract method to return human readable titles both for the RichText
    # (HTML) widget and for menuentries. Also specify id which is used when
    # user select module.
    # @return [Map] with keys "rich_text_title", "menu_title" and "id".
    # @see Description API method
    def description
      raise NotImplementedError, "Calling abstract method 'description'"
    end

    # Optional abstract method to write settings.
    # @return true if succeed
    # @see Write API method
    def write(attrs)
      log.error "Write called, but proposal do not implement it"

      nil
    end
  end
end
