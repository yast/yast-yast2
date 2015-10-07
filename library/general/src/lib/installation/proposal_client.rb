require "yast"

module Installation
  # Abstract class that simplifies writing proposal clients for installation.
  # It provides a single entry point
  # which dispatches calls to the abstract methods that all proposal clients
  # need to implement.
  #
  # It is recommended to use {Installation::ProposalClient} as base class for
  # new clients.
  #
  # @example how to run a client
  #   require "installation/example_proposal"
  #   ::Installation::ExampleProposal.run
  # @see for example client in installation clone_proposal.rb
  #
  # # API for YaST2 installation proposal
  #
  # ## Motivation
  #
  # After five releases, YaST2 is now smart enough to make reasonable
  # proposals for (nearly) every installation setting, thus it is no longer
  # necessary to ask the user that many questions during installation:
  # Most users simply hit the [next] button anyway.
  #
  # Hence, YaST2 now collects all the individual proposals from its submodules
  # and presents them for confirmation right away. The user can change each
  # individual setting, but he is no longer required to go through all the
  # steps just to change some simple things. The only that (currently) really
  # has to be queried is the installation language - this cannot reasonably be
  # guessed (yet?).
  #
  # ## Overview
  #
  # YaST2 installation modules should cooperate with the main program in a
  # consistent API. General usage:
  #
  # * inst_proposal (main program) creates an empty dialog with RichText widget
  #
  # * inst_proposal calls each sub-module in turn to make a proposal
  #
  # * the user may choose to change individual settings
  #   (by clicking on a hyperlink)
  #
  # * inst_proposal starts that module's sub-workflow which runs
  #   independently.  After this, inst_proposal tells all subsequent (all?)
  #   modules to check their states and return whether a change of their
  #   proposal is necessary after the user interaction.
  #
  # * main program calls each sub-module to write the settings to the system
  #
  # ## The `Write` method
  #
  # In addition to the methods defined (and documented) in
  # {Installation::ProposalClient}, there's a method called `Write` which will
  # write the proposed (and probably modified) settings to the system.
  #
  # It is up to the proposal dispatcher how it remembers the settings. The
  # errors must be reported using the Report:: module to have the possibility
  # to control the behaviour from the main program.
  #
  # This `Write` method is optional. The dispatcher module is required to allow
  # this method to be called without returning an error value if it is not
  # there.
  #
  # #### Return Values
  #
  # Returns true, if the settings were written successfully.
  class ProposalClient < Yast::Client
    include Yast::Logger

    # The entry point for calling a client.
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
      when "MakeProposal"
        make_proposal(param)
      when "AskUser"
        ask_user(param)
      when "Description"
        description
      when "Write"
        write(param)
      else
        raise ArgumentError, "Invalid action for proposal '#{func.inspect}'"
      end
    end

  protected

    # Abstract method to create proposal suggestion for installation
    #
    # @option attrs [Boolean] "force_reset"
    #   If `true`, discard anything that may be cached
    #   and start over from scratch.
    #   If `false`, use cached values from the last invocation if there are any.
    #
    # @option attrs [Boolean] "language_changed"
    #   The installation language has changed since the last call of
    #   {#make_proposal}.
    #   This is important only if there is a language change mechanism
    #   in one of the other submodules.
    #   If this parameter is "true", any texts the user can see in
    #   the proposal need to be retranslated. The internal translator mechanism
    #   will take care of this itself if the corresponding strings are once more
    #   put through it (the `_("...")` function). Only very few
    #   submodules that translate any strings internally based on internal maps
    #   (e.g., keyboard etc.) need to take more action.
    #
    # @return [Hash] containing:
    #
    #   * **`"links"`** [Array<String>] ---
    #     A list of additional hyperlink IDs used in summaries returned by this
    #     section. All possible values must be included.
    #
    #   * **`"preformatted_proposal"`** [String, nil] ---
    #     Human readable proposal preformatted in HTML. It is possible to use
    #     the {Yast::HTMLClass Yast::HTML} module for such formatting.
    #
    #   * **`"raw_proposal"`** [Array<String>, nil]
    #     (only used if `preformatted_proposal` is not present) ---
    #     Human readable proposal, not formatted yet.
    #     The caller will format each item as a HTML list item (`<li>`). The
    #     proposal can contain hyperlinks with IDs listed in the list `links`.
    #
    #   * **`"warning"`** [String, nil] ---
    #     Warning in human readable format without HTML tags other than `\<br>`.
    #     The warning will be embedded in appropriate HTML format specifications
    #     according to `warning_level` below.
    #
    #   * **`"warning_level"`** [Symbol, nil] ---
    #     Determines the severity and the visual display of the warning.
    #     The valid values are
    #     `:notice`, `:warning` (default), `:error`, `:blocker` and `:fatal`.
    #     A _blocker_ will prevent the user from continuing the installation.
    #     If any proposal contains a _blocker_ warning, the Accept
    #     button in the proposal dialog will be disabled - the user needs
    #     to fix that blocker before continuing.
    #     _Fatal_ is like _blocker_ but also stops building the proposal.
    #
    #   * **`"language_changed"`** [Boolean] ---
    #     This module just caused a change of the installation language.
    #     This is only relevant for the "language" module.
    #
    #   * **`"mode_changed"`** [Boolean, nil] ---
    #     This module just caused a change of the installation mode.
    #     This is only relevant for the "inst mode" module.
    #
    #   * **`"rootpart_changed"`** [Boolean, nil] ---
    #     This module just caused a change of the root partition.
    #     This is only relevant for the "root part" module.
    #
    #   * **`"help"`** [String, nil] ---
    #     Help text for this module which appears in the standard dialog
    #     help (particular helps for modules sorted by presentation order).
    #
    #   * **`"trigger"`** [Hash, nil] defines circumstances when the proposal
    #     should be called again at the end. For instance, when partitioning or
    #     software selection changes. Mandatory keys of the trigger are:
    #       * **`"expect"`** [Hash] containing _string_ `class` and _string_
    #         `method` that will be called and its result compared with `value`.
    #       * **`"value"`** [Object] expected value, if evaluated code does not
    #         match the `value`, proposal will be called again.
    #
    # @example Triggers definition
    #     {
    #       "trigger" => {
    #         "expect" => {
    #           "class"  => "Yast::Packages",
    #           "method" => "CountSizeToBeDownloaded"
    #         },
    #         "value" => 88883333
    #       }
    #     }
    def make_proposal(_attrs)
      raise NotImplementedError, "Calling abstract method 'make_proposal'"
    end

    # An abstract method to run an interactive workflow -- let the user
    # decide upon values he might want to change.
    #
    # It may contain one single dialog, a sequence of dialogs, or one master
    # dialog with one or more "expert" dialogs. It can also be a non-interactive
    # response to clicking on a hyperlink. The module is responsible for
    # controlling the workflow sequence (i.e., "Next", "Back" buttons etc.).
    #
    # Submodules do not provide an "Abort" button to abort the entire
    # installation. If the user wishes to do that, he can always go back to
    # the main dialog (the installation proposal) and choose "Abort" there.
    #
    # @option attrs [Boolean] "has_next"
    #   Use a "Next" button even if the module by itself has only one step, thus
    #   would normally have an "OK" button - or would rename the "Next" button
    #   to something like "Finish" or "Accept".
    #
    # @option attrs [String, nil] "chosen_id"
    #   If a section proposal contains hyperlinks and the user clicks
    #   on one of them, this defines the ID of the hyperlink.
    #   All hyperlink IDs must be set in the map returned by {#description}.
    #   If the user did not click on a proposal hyperlink,
    #   this parameter is not defined.
    #
    # @return [Hash] containing:
    #
    #   * **`"workflow_sequence"`** [Symbol] with these possible values:
    #
    #       * `:next` (default) --- Everything OK - continue with the next
    #                               step in workflow sequence.
    #
    #       * `:back`   --- User requested to go back in the workflow sequence.
    #
    #       * `:again`  --- Call this submodule again
    #                       (i.e., re-initialize the submodule)
    #
    #       * `:auto`   --- Continue with the workflow sequence in the current
    #                       direction: forward if the last submodule returned
    #                       `:next`, backward otherwise.
    #
    #       * `:finish` --- Finish the installation. This is specific
    #                       to "inst_mode.ycp" when the user selected
    #                       "boot system" there.
    #
    #   * **`"language_changed"`** [Boolean, nil] ---
    #     This module just caused a change of the installation language.
    #     This is only relevant for the "language" module.
    #
    def ask_user(_attrs)
      raise NotImplementedError, "Calling abstract method 'ask_user'"
    end

    # An abstract method to return human readable titles both for the RichText
    # (HTML) widget and for menu entries. It also specifies an ID which is used
    # when the user selects the module.
    #
    # @return [Hash] containing:
    #
    #   * **`"rich_text_title"`** [String] ---
    #     A translated human readable title for this section in
    #     the `RichText` widget without any HTML formatting.
    #     This will be embedded in `<h3><a href="#???"> ... </a></h3>`
    #     so make sure not to add any additional HTML formatting.
    #     Keyboard shortcuts are not (yet?) supported, so do not include
    #     any `&` characters.
    #
    #   * **`"menu_title"`** [String] ---
    #     A translated human readable menu entry for this section.
    #     It must contain a keyboard shortcut (`&`). It should NOT contain
    #     a trailing ellipsis (`...`), the caller will add it.
    #
    #   * **`"id"`** [String] ---
    #     A programmer-readable unique identifier for this section. This is not
    #     auto-generated to keep the log file readable.
    #
    #   This map may be empty. In this case, this proposal section will silently
    #   be ignored. Proposal modules may use this if there is no useful proposal
    #   at all. Use with caution - this may be confusing for the user.
    #
    #   In this case, all other proposal functions must return a useful success
    #   value so they can be called without problems.
    #
    def description
      raise NotImplementedError, "Calling abstract method 'description'"
    end
  end
end
