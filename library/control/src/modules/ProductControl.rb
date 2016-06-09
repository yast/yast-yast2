# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2002 - 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# ***************************************************************************
# File:	modules/ProductControl.rb
# Package:	installation
# Summary:	Product Control routines
# Authors:	Anas Nashif <nashif@suse.de>
#		Stanislav Visnovsky <visnov@suse.cz>
#		Jiri Srain <jsrain@suse.cz>
#		Lukas Ocilka <locilka@suse.cz>
#
require "yast"

module Yast
  class ProductControlClass < Module
    def main
      Yast.import "UI"
      textdomain "base"

      Yast.import "XML"
      Yast.import "ProductFeatures"
      Yast.import "Mode"
      Yast.import "Arch"
      Yast.import "Stage"
      Yast.import "Directory"
      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "Report"
      Yast.import "DebugHooks"
      Yast.import "Popup"
      Yast.import "FileUtils"
      Yast.import "Installation"
      Yast.import "Hooks"

      # The complete parsed control file
      @productControl = {}

      # all workflows
      @workflows = []

      # all proposals
      @proposals = []

      # inst_finish steps
      @inst_finish = []

      # modules to be offered to clone configuration at the end of installation
      @clone_modules = []

      # additional workflow parameters
      # workflow doesn't only match mode and stage but also these params
      # bnc #427002
      @_additional_workflow_params = {}

      # Location of a custom control file
      @custom_control_file = ""

      # Control file in service packs
      @y2update_control_file = "/y2update/control.xml"

      # The custom control file location, usually copied from
      # the root of the CD to the installation directory by linuxrc
      @installation_control_file = "/control.xml"

      # The file above get saved into the installed system for later
      # processing
      @saved_control_file = Ops.add(Directory.etcdir, "/control.xml")

      # The control file we are using for this session.
      @current_control_file = nil

      # Current Wizard Step
      @CurrentWizardStep = ""

      # Last recently used stage_mode for RetranslateWizardSteps
      @last_stage_mode = []

      # List of module to disable in the current run
      @DisabledModules = []

      # List of proposals to disable in the current run
      @DisabledProposals = []

      @DisabledSubProposals = {}

      # Log files for hooks
      @logfiles = []

      @first_step = nil

      @restarting_step = nil

      @_client_prefix = "inst_"

      @stack = []

      @first_id = ""

      @current_step = 0

      @localDisabledProposals = []

      @localDisabledModules = []

      @already_disabled_workflows = []

      # Forces UpdateWizardSteps to redraw steps even if nothing seem to be changed
      @force_UpdateWizardSteps = false

      @lastDisabledModules = deep_copy(@DisabledModules)

      ProductControl()
    end

    def CurrentStep
      @current_step
    end

    # Set Client Prefix
    def setClientPrefix(prefix)
      @_client_prefix = prefix
      nil
    end

    # Enable given disabled module
    # @return current list of disabled modules
    def EnableModule(modname)
      @DisabledModules = Builtins.filter(@DisabledModules) do |mod|
        mod != modname
      end

      deep_copy(@DisabledModules)
    end

    # Disable given module in installation workflow
    # @return current list of disabled modules
    def DisableModule(modname)
      if modname.nil? || modname == ""
        Builtins.y2error("Module to disable is '%1'", modname)
      else
        @DisabledModules = Convert.convert(
          Builtins.union(@DisabledModules, [modname]),
          from: "list",
          to:   "list <string>"
        )
      end

      deep_copy(@DisabledModules)
    end

    # Returns list of modules disabled in workflow
    #
    # @return [Array<String>] DisabledModules
    def GetDisabledModules
      deep_copy(@DisabledModules)
    end

    # Enable given disabled proposal
    # @return current list of disabled proposals
    def EnableProposal(enable_proposal)
      @DisabledProposals = Builtins.filter(@DisabledProposals) do |one_proposal|
        one_proposal != enable_proposal
      end

      deep_copy(@DisabledProposals)
    end

    # Disable given proposal in installation workflow
    # @return current list of disabled proposals
    def DisableProposal(disable_proposal)
      if disable_proposal.nil? || disable_proposal == ""
        Builtins.y2error("Module to disable is '%1'", disable_proposal)
      else
        @DisabledProposals = Convert.convert(
          Builtins.union(@DisabledProposals, [disable_proposal]),
          from: "list",
          to:   "list <string>"
        )
      end

      deep_copy(@DisabledProposals)
    end

    # Returns list of proposals disabled in workflow
    #
    # @return [Array<String>] DisabledProposals
    def GetDisabledProposals
      deep_copy(@DisabledProposals)
    end

    def EnableSubProposal(unique_id, enable_subproposal)
      if Builtins.haskey(@DisabledSubProposals, unique_id)
        Ops.set(
          @DisabledSubProposals,
          unique_id,
          Builtins.filter(Ops.get(@DisabledSubProposals, unique_id, [])) do |one_subproposal|
            one_subproposal != enable_subproposal
          end
        )
      end
      deep_copy(@DisabledSubProposals)
    end

    def DisableSubProposal(unique_id, disable_subproposal)
      if Builtins.haskey(@DisabledSubProposals, unique_id)
        Ops.set(
          @DisabledSubProposals,
          unique_id,
          Convert.convert(
            Builtins.union(
              Ops.get(@DisabledSubProposals, unique_id, []),
              [disable_subproposal]
            ),
            from: "list",
            to:   "list <string>"
          )
        )
      else
        Ops.set(@DisabledSubProposals, unique_id, [disable_subproposal])
      end

      deep_copy(@DisabledSubProposals)
    end

    def GetDisabledSubProposals
      deep_copy(@DisabledSubProposals)
    end

    # Check if a module is disabled
    # @param map module map
    # @return [Boolean]
    def checkDisabled(mod)
      mod = deep_copy(mod)
      if mod.nil?
        Builtins.y2error("Unknown module %1", mod)
        return nil
      end

      # Proposal
      if !Ops.get_string(mod, "proposal", "").nil? &&
          Ops.get_string(mod, "proposal", "") != ""
        if Builtins.contains(
          @DisabledProposals,
          Ops.get_string(mod, "proposal", "")
        )
          return true
        end
        # Normal step
      elsif !Ops.get_string(mod, "name", "").nil? &&
          Ops.get_string(mod, "name", "") != ""
        if Builtins.contains(@DisabledModules, Ops.get_string(mod, "name", ""))
          return true
        end
      end

      false
    end

    def checkHeading(mod)
      mod = deep_copy(mod)
      Builtins.haskey(mod, "heading")
    end

    # Read XML Control File
    # @param string control file
    # @return [Boolean]
    def ReadControlFile(controlfile)
      @productControl = XML.XMLToYCPFile(controlfile)

      return false if @productControl.nil?

      @workflows = Ops.get_list(@productControl, "workflows", [])
      @proposals = Ops.get_list(@productControl, "proposals", [])
      @inst_finish = Ops.get_list(@productControl, "inst_finish_stages", [])
      @clone_modules = Ops.get_list(@productControl, "clone_modules", [])

      Builtins.foreach(
        ["software", "globals", "network", "partitioning", "texts"]
      ) do |section|
        if Builtins.haskey(@productControl, section)
          ProductFeatures.SetSection(
            section,
            Ops.get_map(@productControl, section, {})
          )
        end
      end

      # FIXME: would be nice if it could be done generic way
      if Ops.greater_than(
        Builtins.size(
          Ops.get_list(@productControl, ["partitioning", "partitions"], [])
        ),
        0
      )
        partitioning = Ops.get_map(@productControl, "partitioning", {})
        ProductFeatures.SetBooleanFeature(
          "partitioning",
          "flexible_partitioning",
          true
        )
        ProductFeatures.SetFeature(
          "partitioning",
          "FlexiblePartitioning",
          partitioning
        )
      end

      true
    end

    def Check(allowed, current)
      # create allowed list
      allowedlist = Builtins.filter(
        Builtins.splitstring(Builtins.deletechars(allowed, " "), ",")
      ) { |s| s != "" }
      Builtins.y2debug("allowedlist: %1", allowedlist)
      Builtins.y2debug("current: %1", current)
      if Builtins.size(allowedlist) == 0
        return true
      elsif Builtins.contains(allowedlist, current)
        return true
      else
        return false
      end
    end

    # Check if valid architecture
    # @param map module data
    # @param map default data
    # @return [Boolean] true if arch match
    def checkArch(mod, def_)
      mod = deep_copy(mod)
      def_ = deep_copy(def_)
      Builtins.y2debug("Checking architecture: %1", mod)
      archs = Ops.get_string(mod, "archs", "")
      archs = Ops.get_string(def_, "archs", "all") if archs == ""

      return true if archs == "all"

      Builtins.y2milestone("short arch desc: %1", Arch.arch_short)
      Builtins.y2milestone("supported archs: %1", archs)
      return true if Builtins.issubstring(archs, Arch.arch_short)

      false
    end

    # Returns name of the script to call. If 'execute' is defined,
    # the client name is taken from there. Then, if a custom control
    # file is defined, client name is defined as 'name'. Then, inst_'name'
    # or just 'name' is returned if it does not match the 'inst_' regexp.
    #
    # @param [String] name
    # @param [String] execute
    # @see #custom_control_file
    def getClientName(name, execute)
      return "inst_test_workflow" if Mode.test

      # BNC #401319
      # 'execute; is defined and thus returned
      if !execute.nil? && execute != ""
        Builtins.y2milestone("Step name '%1' executes '%2'", name, execute)
        return execute
      end

      # Defined custom control file
      if @custom_control_file != ""
        return name

        # All standard clients start with "inst_"
      else
        if Builtins.issubstring(name, @_client_prefix)
          return name
        else
          return Ops.add(@_client_prefix, name)
        end
      end
    end

    # Return term to be used to run module with CallFunction
    # @param map module data
    # @param map default data
    # @return [Yast::Term] module data with params
    def getClientTerm(step, def_, former_result)
      step = deep_copy(step)
      def_ = deep_copy(def_)
      former_result = deep_copy(former_result)
      client = getClientName(
        Ops.get_string(step, "name", "dummy"),
        Ops.get_string(step, "execute", "")
      )
      result = Builtins.toterm(client)
      arguments = {}

      Builtins.foreach(["enable_back", "enable_next"]) do |button|
        default_setting = Ops.get_string(def_, button, "yes")
        Ops.set(
          arguments,
          button,
          Ops.get_string(step, button, default_setting) == "yes"
        )
      end

      if Builtins.haskey(step, "proposal")
        Ops.set(arguments, "proposal", Ops.get_string(step, "proposal", ""))
      end
      other_args = Ops.get_map(step, "arguments", {})

      if Ops.greater_than(Builtins.size(other_args), 0)
        arguments = Convert.convert(
          Builtins.union(arguments, other_args),
          from: "map",
          to:   "map <string, any>"
        )
      end

      if Ops.is_symbol?(former_result) && former_result == :back
        Ops.set(arguments, "going_back", true)
      end

      if Mode.test
        Ops.set(arguments, "step_name", Ops.get_string(step, "name", ""))
        Ops.set(arguments, "step_id", Ops.get_string(step, "id", ""))
      end
      result = Builtins.add(result, arguments)
      deep_copy(result)
    end

    # Checks all params set by SetAdditionalWorkflowParams() whether they match the
    # workfow got as parameter.
    #
    # @param [map &] check_workflow
    # @see #SetAdditionalWorkflowParams()
    def CheckAdditionalParams(check_workflow)
      if @_additional_workflow_params.nil? ||
          @_additional_workflow_params == {}
        return true
      end

      ret = true

      Builtins.foreach(@_additional_workflow_params) do |key_to_check, value_to_check|
        # exception
        # If 'add_on_mode' key is not set in the workflow at all
        # it is considered to be matching that parameter
        if key_to_check == "add_on_mode" &&
            !Builtins.haskey(check_workflow.value, key_to_check)
          Builtins.y2debug(
            "No 'add_on_mode' defined, matching %1",
            value_to_check
          )
        elsif Ops.get(check_workflow.value, key_to_check) != value_to_check
          ret = false
          raise Break
        end
      end

      ret
    end

    # Returns workflow matching the selected stage and mode and additiona parameters
    # if set by SetAdditionalWorkflowParams()
    #
    # @param [String] stage
    # @param [String] mode
    # @return [Hash] workflow
    def FindMatchingWorkflow(stage, mode)
      Builtins.y2debug("workflows: %1", @workflows)

      tmp = Builtins.filter(@workflows) do |wf|
        Check(Ops.get_string(wf, "stage", ""), stage) &&
          Check(Ops.get_string(wf, "mode", ""), mode) &&
          (
            wf_ref = arg_ref(wf)
            CheckAdditionalParams(wf_ref)
          )
      end

      Builtins.y2debug("Workflow: %1", Ops.get(tmp, 0, {}))

      Ops.get(tmp, 0, {})
    end

    # Get workflow defaults
    # @param [String] stage
    # @param [String] mode
    # @return [Hash] defaults
    def getModeDefaults(stage, mode)
      workflow = FindMatchingWorkflow(stage, mode)
      Ops.get_map(workflow, "defaults", {})
    end

    # Prepare Workflow Scripts
    # @param [Hash] m Workflow module map
    # @return [void]
    def PrepareScripts(m)
      m = deep_copy(m)
      tmp_dir = Convert.to_string(WFM.Read(path(".local.tmpdir"), []))
      if Builtins.haskey(m, "prescript")
        interpreter = Ops.get_string(m, ["prescript", "interpreter"], "shell")
        source = Ops.get_string(m, ["prescript", "source"], "")
        type = interpreter == "shell" ? "sh" : "pl"
        f = Builtins.sformat(
          "%1/%2_pre.%3",
          tmp_dir,
          Ops.get_string(m, "name", ""),
          type
        )
        WFM.Write(path(".local.string"), f, source)
        @logfiles = Builtins.add(
          @logfiles,
          Builtins.sformat(
            "%1.log",
            Builtins.sformat("%1_pre.%2", Ops.get_string(m, "name", ""), type)
          )
        )
      end
      if Builtins.haskey(m, "postscript")
        interpreter = Ops.get_string(m, ["postscript", "interpreter"], "shell")
        source = Ops.get_string(m, ["postscript", "source"], "")
        type = interpreter == "shell" ? "sh" : "pl"
        f = Builtins.sformat(
          "%1/%2_post.%3",
          tmp_dir,
          Ops.get_string(m, "name", ""),
          type
        )
        WFM.Write(path(".local.string"), f, source)
        @logfiles = Builtins.add(
          @logfiles,
          Builtins.sformat(
            "%1.log",
            Builtins.sformat("%1_post.%2", Ops.get_string(m, "name", ""), type)
          )
        )
      end
      nil
    end

    # Get list of required files for the workflow.
    # @return [Array<String>] Required files list.
    # FIXME: this function seems to be unused, remove it?
    def RequiredFiles(stage, mode)
      # Files needed during installation.
      needed_client_files = []

      workflow = FindMatchingWorkflow(stage, mode)

      modules = Ops.get_list(workflow, "modules", [])
      modules = Builtins.filter(modules) do |m|
        Ops.get_boolean(m, "enabled", true)
      end

      Builtins.foreach(modules) do |m|
        client = ""
        if Stage.firstboot
          client = Ops.get_string(m, "name", "dummy")
        else
          if Builtins.issubstring(Ops.get_string(m, "name", "dummy"), "inst_")
            client = Ops.get_string(m, "name", "dummy")
          else
            client = Ops.add("inst_", Ops.get_string(m, "name", "dummy"))
          end
        end
        # FIXME: what about the ruby files?
        client = Ops.add(
          Ops.add(Ops.add(Directory.clientdir, "/"), client),
          ".ycp"
        )
        needed_client_files = Builtins.add(needed_client_files, client)
      end

      needed_client_files = Builtins.toset(needed_client_files)
      deep_copy(needed_client_files)
    end

    # Get Workflow
    # @param [String] stage Stage
    # @param [String] mode Mode
    # @return [Hash] Workflow map
    def getCompleteWorkflow(stage, mode)
      FindMatchingWorkflow(stage, mode)
    end

    # Get modules of current Workflow
    # @param [String] stage
    # @param [String] mode
    # @param boolean all enabled and disabled or enabled only
    # @return [Array<Hash>] modules
    def getModules(stage, mode, which)
      workflow = FindMatchingWorkflow(stage, mode)

      modules = Ops.get_list(workflow, "modules", [])
      Builtins.y2debug("M1: %1", modules)

      # Unique IDs have to always keep the same because some steps
      # can be disabled while YaST is running
      # @see BNC #575092
      id = 1
      modules = Builtins.maplist(modules) do |m|
        Ops.set(m, "id", Builtins.sformat("%1_%2", stage, id))
        id = Ops.add(id, 1)
        deep_copy(m)
      end

      modules = Builtins.filter(modules) do |m|
        Ops.get_boolean(m, "enabled", true) && !checkDisabled(m)
      end if which == :enabled

      Builtins.y2debug("M2: %1", modules)

      modules = Builtins.maplist(modules) do |m|
        PrepareScripts(m)
        deep_copy(m)
      end

      Builtins.y2debug("M3: %1", modules)
      Builtins.y2debug("Log files: %1", @logfiles)
      deep_copy(modules)
    end

    # Returns whether is is required to run YaST in the defined
    # stage and mode
    #
    # @param [String] stage
    # @param [String] mode
    # @return [Boolean] if needed
    def RunRequired(stage, mode)
      modules = getModules(stage, mode, :enabled)

      if modules.nil?
        Builtins.y2error("Undefined %1/%2", stage, mode)
        return nil
      end

      modules = Builtins.filter(modules) do |one_module|
        # modules
        if !Ops.get_string(one_module, "name").nil? &&
            Ops.get_string(one_module, "name", "") != ""
          next true
          # proposals
        elsif !Ops.get_string(one_module, "proposal").nil? &&
            Ops.get_string(one_module, "proposal", "") != ""
          next true
        end
        # the rest
        false
      end

      # for debugging purposes
      Builtins.y2milestone("Enabled: (%1) %2", Builtins.size(modules), modules)

      Ops.greater_than(Builtins.size(modules), 0)
    end

    # Get Workflow Label
    # @param [String] stage
    # @param [String] mode
    # @return [String]
    def getWorkflowLabel(stage, mode, wz_td)
      workflow = FindMatchingWorkflow(stage, mode)

      label = Ops.get_string(workflow, "label", "")
      return "" if label == ""
      if Builtins.haskey(workflow, "textdomain")
        return Builtins.dgettext(
          Ops.get_string(workflow, "textdomain", ""),
          label
        )
      else
        return Builtins.dgettext(wz_td, label)
      end
    end

    def DisableAllModulesAndProposals(mode, stage)
      this_workflow = { "mode" => mode, "stage" => stage }

      if Builtins.contains(@already_disabled_workflows, this_workflow)
        Builtins.y2milestone("Workflow %1 already disabled", this_workflow)
        return
      end

      # stores modules and proposals disabled before
      # this 'general' disabling
      @localDisabledProposals = deep_copy(@DisabledProposals)
      @localDisabledModules = deep_copy(@DisabledModules)

      Builtins.y2milestone(
        "localDisabledProposals: %1",
        @localDisabledProposals
      )
      Builtins.y2milestone("localDisabledModules: %1", @localDisabledModules)

      Builtins.foreach(getModules(stage, mode, :all)) do |m|
        if !Ops.get_string(m, "proposal").nil? &&
            Ops.get_string(m, "proposal", "") != ""
          Builtins.y2milestone("Disabling proposal: %1", m)
          @DisabledProposals = Convert.convert(
            Builtins.union(
              @DisabledProposals,
              [Ops.get_string(m, "proposal", "")]
            ),
            from: "list",
            to:   "list <string>"
          )
        elsif !Ops.get_string(m, "name").nil? &&
            Ops.get_string(m, "name", "") != ""
          Builtins.y2milestone("Disabling module: %1", m)
          @DisabledModules = Convert.convert(
            Builtins.union(@DisabledModules, [Ops.get_string(m, "name", "")]),
            from: "list",
            to:   "list <string>"
          )
        end
      end

      @already_disabled_workflows = Convert.convert(
        Builtins.union(@already_disabled_workflows, [this_workflow]),
        from: "list",
        to:   "list <map>"
      )

      nil
    end

    def UnDisableAllModulesAndProposals(mode, stage)
      this_workflow = { "mode" => mode, "stage" => stage }

      # Such mode/stage not disabled
      if !Builtins.contains(@already_disabled_workflows, this_workflow)
        Builtins.y2milestone(
          "Not yet disabled, not un-disabling: %1",
          this_workflow
        )
        return
      end

      Builtins.y2milestone("Un-Disabling workflow %1", this_workflow)
      @already_disabled_workflows = Builtins.filter(@already_disabled_workflows) do |one_workflow|
        one_workflow != this_workflow
      end

      # Note: This might be done by a simple reverting with 'X = localX'
      #       but some of these modules don't need to be in a defined mode and stage

      Builtins.foreach(getModules(stage, mode, :all)) do |m|
        # A proposal
        # Enable it only if it was enabled before
        if !Ops.get_string(m, "proposal").nil? &&
            Ops.get_string(m, "proposal", "") != "" &&
            !Builtins.contains(
              @localDisabledProposals,
              Ops.get_string(m, "proposal", "")
            )
          Builtins.y2milestone("Enabling proposal: %1", m)
          @DisabledProposals = Builtins.filter(@DisabledProposals) do |one_proposal|
            Ops.get_string(m, "proposal", "") != one_proposal
          end
          # A module
          # Enable it only if it was enabled before
        elsif !Ops.get_string(m, "name").nil? &&
            Ops.get_string(m, "name", "") != "" &&
            !Builtins.contains(
              @localDisabledModules,
              Ops.get_string(m, "name", "")
            )
          Builtins.y2milestone("Enabling module: %1", m)
          @DisabledModules = Builtins.filter(@DisabledModules) do |one_module|
            Ops.get_string(m, "name", "") != one_module
          end
        end
      end

      nil
    end

    # Add Wizard Steps
    # @param [Array<Hash>] stagemode A List of maps containing info about complete
    #                  installation workflow.
    # @return [void]
    def AddWizardSteps(stagemode)
      stagemode = deep_copy(stagemode)
      debug_workflow = ProductFeatures.GetBooleanFeature(
        "globals",
        "debug_workflow"
      )

      @last_stage_mode = deep_copy(stagemode)

      # UI::WizardCommand() can safely be called even if the respective UI
      # doesn't support the wizard widget, but for optimization it makes sense
      # to do expensive operations only when it is available.

      # if ( ! UI::HasSpecialWidget(`Wizard ) )
      # return;

      wizard_textdomain = Ops.get_string(
        @productControl,
        "textdomain",
        "control"
      )
      Builtins.y2debug(
        "Using textdomain '%1' for wizard steps",
        wizard_textdomain
      )

      first_id = ""
      # UI::WizardCommand(`SetVerboseCommands( true ) );
      Builtins.foreach(stagemode) do |sm|
        Builtins.y2debug("Adding wizard steps for %1", sm)
        # only for debugging
        Builtins.y2milestone("Adding wizard steps for %1", sm)
        slabel = getWorkflowLabel(
          Ops.get_string(sm, "stage", ""),
          Ops.get_string(sm, "mode", ""),
          wizard_textdomain
        )
        UI.WizardCommand(term(:AddStepHeading, slabel)) if slabel != ""
        # just to check whether there are some steps to display
        enabled_modules = getModules(
          Ops.get_string(sm, "stage", ""),
          Ops.get_string(sm, "mode", ""),
          :enabled
        )
        enabled_modules = Builtins.filter(enabled_modules) do |m|
          Ops.get_string(m, "heading", "") == ""
        end
        if Builtins.size(enabled_modules) == 0
          Builtins.y2milestone(
            "There are no (more) steps for %1, section will be disabled",
            sm
          )
          next
        end
        last_label = ""
        last_domain = ""
        Builtins.foreach(
          getModules(
            Ops.get_string(sm, "stage", ""),
            Ops.get_string(sm, "mode", ""),
            :enabled
          )
        ) do |m|
          # only for debugging
          Builtins.y2debug("Adding wizard step: %1", m)
          heading = ""
          label = ""
          id = ""
          # Heading
          if Builtins.haskey(m, "heading") &&
              Ops.get_string(m, "label", "") != ""
            heading = if Builtins.haskey(m, "textdomain")
                        Builtins.dgettext(
                          Ops.get_string(m, "textdomain", ""),
                          Ops.get_string(m, "label", "")
                        )
                      else
                        Builtins.dgettext(
                          wizard_textdomain,
                          Ops.get_string(m, "label", "")
                        )
                      end

          # Label
          elsif Ops.get_string(m, "label", "") != ""
            first_id = Ops.get_string(m, "id", "") if first_id == ""

            label = if Builtins.haskey(m, "textdomain")
                      Builtins.dgettext(
                        Ops.get_string(m, "textdomain", ""),
                        Ops.get_string(m, "label", "")
                      )
                    else
                      Builtins.dgettext(
                        wizard_textdomain,
                        Ops.get_string(m, "label", "")
                      )
                    end

            id = Ops.get_string(m, "id", "")
            last_label = Ops.get_string(m, "label", "")
            last_domain = Ops.get_string(m, "textdomain", "")

            # The rest
          else
            first_id = Ops.get_string(m, "id", "") if first_id == ""

            if last_label != ""
              if last_domain != ""
                label = Builtins.dgettext(last_domain, last_label)
                id = Ops.get_string(m, "id", "")
              else
                label = Builtins.dgettext(wizard_textdomain, last_label)
              end
              id = Ops.get_string(m, "id", "")
            end
          end
          if !heading.nil? && heading != ""
            UI.WizardCommand(term(:AddStepHeading, heading))
          end
          if !label.nil? && label != ""
            if debug_workflow == true
              label = Ops.add(
                label,
                Builtins.sformat(" [%1]", Ops.get_string(m, "name", ""))
              )
            end
            Builtins.y2debug("AddStep: %1/%2", label, id)
            UI.WizardCommand(term(:AddStep, label, id))
          end
        end
      end

      UI.WizardCommand(term(:SetCurrentStep, @CurrentWizardStep))

      nil
    end

    # Update Steps
    def UpdateWizardSteps(stagemode)
      stagemode = deep_copy(stagemode)
      if @force_UpdateWizardSteps == true
        Builtins.y2milestone("UpdateWizardSteps forced")
        @force_UpdateWizardSteps = false
      elsif @DisabledModules != @lastDisabledModules
        Builtins.y2milestone("Disabled modules were changed")
      elsif @last_stage_mode == stagemode
        Builtins.y2milestone("No changes in Wizard steps")
        return
      end

      @last_stage_mode = deep_copy(stagemode)
      @lastDisabledModules = deep_copy(@DisabledModules)

      UI.WizardCommand(term(:DeleteSteps))
      # Also redraws the wizard and sets the current step
      AddWizardSteps(stagemode)

      nil
    end

    # Retranslate Wizard Steps
    def RetranslateWizardSteps
      if Ops.greater_than(Builtins.size(@last_stage_mode), 0)
        Builtins.y2debug("Retranslating wizard steps")
        @force_UpdateWizardSteps = true
        UpdateWizardSteps(@last_stage_mode)
      end

      nil
    end

    def getMatchingProposal(stage, mode, proptype)
      Builtins.y2milestone(
        "Stage: %1 Mode: %2, Type: %3",
        stage,
        mode,
        proptype
      )

      # First we search for proposals for current stage if there are
      # any.
      props = Builtins.filter(@proposals) do |p|
        Check(Ops.get_string(p, "stage", ""), stage)
      end
      Builtins.y2debug("1. proposals: %1", props)

      # Then we check for mode: installation or update
      props = Builtins.filter(props) do |p|
        Check(Ops.get_string(p, "mode", ""), mode)
      end

      Builtins.y2debug("2. proposals: %1", props)

      # Now we check for architecture
      Builtins.y2debug(
        "Architecture: %1, Proposals: %2",
        Arch.architecture,
        props
      )

      arch_proposals = Builtins.filter(props) do |p|
        Ops.get_string(p, "name", "") == proptype &&
          Builtins.issubstring(
            Ops.get_string(p, "archs", "dummy"),
            Arch.arch_short
          )
      end

      Builtins.y2debug("3. arch proposals: %1", arch_proposals)

      props = Builtins.filter(props) do |p|
        Ops.get_string(p, "archs", "") == "" ||
          Ops.get_string(p, "archs", "") == "all"
      end

      Builtins.y2debug("4. other proposals: %1", props)
      # If architecture specific proposals are available, we continue with those
      # and check for proposal type, else we continue with pre arch proposal
      # list
      if Ops.greater_than(Builtins.size(arch_proposals), 0)
        props = Builtins.filter(arch_proposals) do |p|
          Ops.get_string(p, "name", "") == proptype
        end
        Builtins.y2debug("5. arch proposals: %1", props)
      else
        props = Builtins.filter(props) do |p|
          Ops.get_string(p, "name", "") == proptype
        end
        Builtins.y2debug("5. other proposals: %1", props)
      end

      if Ops.greater_than(Builtins.size(props), 1)
        Builtins.y2error(
          "Something Wrong happened, more than one proposal after filter:\n                %1",
          props
        )
      end

      # old style proposal
      Builtins.y2milestone(
        "Proposal modules: %1",
        Ops.get(props, [0, "proposal_modules"])
      )
      deep_copy(props)
    end

    # Get modules of current Workflow
    # @param [String] stage
    # @param [String] mode
    # @param [String] proptype eg. "initial", "service", network"...
    # @return [Array<Array(String,Integer)>] modules,
    #   pairs of ("foo_proposal", presentation_order)
    def getProposals(stage, mode, proptype)
      props = getMatchingProposal(stage, mode, proptype)
      unique_id = Ops.get_string(props, [0, "unique_id"], "")
      disabled_subprops = GetDisabledSubProposals()

      final_proposals = []
      Builtins.foreach(Ops.get_list(props, [0, "proposal_modules"], [])) do |p|
        proposal_name = ""
        order_value = 50
        if Ops.is_string?(p)
          proposal_name = Convert.to_string(p)
        else
          pm = Convert.convert(p, from: "any", to: "map <string, string>")
          proposal_name = Ops.get(pm, "name", "")
          proposal_order = Ops.get(pm, "presentation_order", "50")

          order_value = Builtins.tointeger(proposal_order)
          if order_value.nil?
            Builtins.y2error(
              "Unable to use '%1' as proposal order, using %2 instead",
              proposal_order,
              50
            )
            order_value = 50
          end
        end
        is_disabled = Builtins.haskey(disabled_subprops, unique_id) &&
          Builtins.contains(
            Ops.get(disabled_subprops, unique_id, []),
            proposal_name
          )
        # All proposal file names end with _proposal
        if !is_disabled
          if !Builtins.issubstring(proposal_name, "_proposal")
            final_proposals = Builtins.add(
              final_proposals,
              [Ops.add(proposal_name, "_proposal"), order_value]
            )
          else
            final_proposals = Builtins.add(
              final_proposals,
              [proposal_name, order_value]
            )
          end
        else
          Builtins.y2milestone(
            "Proposal module %1 found among disabled subproposals",
            proposal_name
          )
        end
      end

      Builtins.y2debug("final proposals: %1", final_proposals)
      deep_copy(final_proposals)
    end

    # Return text domain
    def getProposalTextDomain
      current_proposal_textdomain = Ops.get_string(
        @productControl,
        "textdomain",
        "control"
      )

      Builtins.y2debug(
        "Using textdomain '%1' for proposals",
        current_proposal_textdomain
      )
      current_proposal_textdomain
    end

    # @param [String] stage
    # @param [String] mode
    # @param [String] proptype eg. "initial", "service", network"...
    # @return [Hash] one "proposal" element of control.rnc
    #   where /label is not translated yet but //proposal_tab/label are.
    def getProposalProperties(stage, mode, proptype)
      got_proposals = getMatchingProposal(stage, mode, proptype)
      proposal = Ops.get(got_proposals, 0, {})

      if Builtins.haskey(proposal, "proposal_tabs")
        text_domain = Ops.get_string(@productControl, "textdomain", "control")
        Ops.set(
          proposal,
          "proposal_tabs",
          Builtins.maplist(Ops.get_list(proposal, "proposal_tabs", [])) do |tab|
            domain = Ops.get_string(tab, "textdomain", text_domain)
            Ops.set(
              tab,
              "label",
              Builtins.dgettext(domain, Ops.get_string(tab, "label", ""))
            )
            deep_copy(tab)
          end
        )
      end

      deep_copy(proposal)
    end

    def GetTranslatedText(key)
      controlfile_texts = ProductFeatures.GetSection("texts")

      if !Builtins.haskey(controlfile_texts, key)
        Builtins.y2error("No such text %1", key)
        return ""
      end

      text = Ops.get_map(controlfile_texts, key, {})

      label = Ops.get(text, "label", "")

      # an empty string doesn't need to be translated
      return "" if label == ""

      domain = Ops.get(
        text,
        "textdomain",
        Ops.get_string(@productControl, "textdomain", "control")
      )
      if domain == ""
        Builtins.y2warning("The text domain for label %1 not set", key)
        return label
      end

      Builtins.dgettext(domain, label)
    end

    # Initialize Product Control
    # @return [Boolean] True on success
    def Init
      # Ordered list
      control_file_candidates = [
        @y2update_control_file,     # /y2update/control.xml
        @installation_control_file, # /control.xml
        @saved_control_file,        # /etc/YaST2/control.xml
      ]

      if @custom_control_file.nil?
        Bultins.y2error("Incorrectly set custom control file: #{@custom_control_file}")
        return false
      end

      control_file_candidates.unshift(@custom_control_file) if !@custom_control_file.empty?

      Builtins.y2milestone("Candidates: #{control_file_candidates.inspect}")
      @current_control_file = control_file_candidates.find { |f| FileUtils.Exists(f) }

      if @current_control_file.nil?
        Builtins.y2error("No control file found within #{control_file_candidates.inspect}")
        return false
      end

      Builtins.y2milestone("Reading control file: #{@current_control_file}")
      ReadControlFile(@current_control_file)

      true
    end

    # Re-translate static part of wizard dialog and other predefined messages
    # after language change
    def retranslateWizardDialog
      Builtins.y2milestone("Retranslating messages, redrawing wizard steps")

      # Make sure the labels for default function keys are retranslated, too.
      # Using Label::DefaultFunctionKeyMap() from Label module.
      UI.SetFunctionKeys(Label.DefaultFunctionKeyMap)

      # Activate language changes on static part of wizard dialog
      RetranslateWizardSteps()
      Wizard.RetranslateButtons
      Wizard.SetFocusToNextButton
      nil
    end

    def addToStack(name)
      @stack = Builtins.add(@stack, name)
      nil
    end

    def wasRun(name)
      Builtins.contains(@stack, name)
    end

    def RunFrom(from, allow_back)
      former_result = :next
      final_result = nil
      @current_step = from # current module

      Wizard.SetFocusToNextButton

      Builtins.y2debug(
        "Starting Workflow with  \"%1\" \"%2\"",
        Stage.stage,
        Mode.mode
      )

      modules = getModules(Stage.stage, Mode.mode, :enabled)

      defaults = getModeDefaults(Stage.stage, Mode.mode)

      Builtins.y2debug("modules: %1", modules)

      if Builtins.size(modules) == 0
        Builtins.y2error("No workflow found: %1", modules)
        # error report
        Report.Error(_("No workflow defined for this installation mode."))
        return :abort
      end

      minimum_step = allow_back ? 0 : from

      if Ops.less_than(minimum_step, from)
        Builtins.y2warning(
          "Minimum step set to: %1 even if running from %2, fixing",
          minimum_step,
          from
        )
        minimum_step = from
      end

      while Ops.greater_or_equal(@current_step, 0) &&
          Ops.less_than(@current_step, Builtins.size(modules))
        step = Ops.get(modules, @current_step, {})
        Builtins.y2milestone("Current step: %1", step)

        step_name = Ops.get_string(step, "name", "")
        # BNC #401319
        # if "execute" is defined, it's called without modifications
        step_execute = Ops.get_string(step, "execute", "")
        step_id = Ops.get_string(step, "id", "")
        run_in_update_mode = Ops.get_boolean(step, "update", true) # default is true
        retranslate = Ops.get_boolean(step, "retranslate", false)

        # The very first dialog has back button disabled
        if Ops.less_or_equal(@current_step, minimum_step)
          # Don't mark back button disabled when back button status
          # is forced in the control file
          if !Builtins.haskey(step, "enable_back")
            Ops.set(step, "enable_back", "no")
            Builtins.y2milestone(
              "Disabling back: %1 %2 %3",
              @current_step,
              minimum_step,
              Ops.get(step, "enable_back")
            )
          end
        end

        do_continue = false

        do_continue = true if !checkArch(step, defaults)

        do_continue = true if checkDisabled(step)

        do_continue = true if checkHeading(step)

        do_continue = true if !run_in_update_mode && Mode.update

        if do_continue
          if former_result == :next
            if Ops.less_or_equal(@current_step, minimum_step) && !allow_back
              minimum_step = Ops.add(minimum_step, 1)
            end
            @current_step = Ops.add(@current_step, 1)
          else
            @current_step = Ops.subtract(@current_step, 1)
          end
        end
        # Continue in 'while' means 'next step'
        next if do_continue

        argterm = getClientTerm(step, defaults, former_result)
        Builtins.y2milestone("Running module: %1 (%2)", argterm, @current_step)

        module_name = Builtins.symbolof(argterm)

        Builtins.y2milestone("Calling %1", argterm)

        if !wasRun(step_name)
          DebugHooks.Checkpoint(Builtins.sformat("%1", module_name), true)
          DebugHooks.Run(step_name, true)
        end

        args = []
        i = 0
        while Ops.less_than(i, Builtins.size(argterm))
          Ops.set(args, i, Ops.get(argterm, i))
          i = Ops.add(i, 1)
        end

        UI.WizardCommand(term(:SetCurrentStep, step_id))
        @CurrentWizardStep = step_id

        # Register what step we are going to run
        if !Stage.initial
          if !SCR.Write(
            path(".target.string"),
            Installation.current_step,
            step_id
          )
            Builtins.y2error("Error writing step identifier")
          end
        end

        Hooks.run("before_#{step_name}")

        result = WFM.CallFunction(getClientName(step_name, step_execute), args)

        # this code will be triggered before the red pop window appears on the user's screen
        Hooks.run("installation_failure") if result == false

        result = Convert.to_symbol(result)

        Hooks.run("after_#{step_name}")

        Builtins.y2milestone("Calling %1 returned %2", argterm, result)

        # bnc #369846
        if result == :accept || result == :ok
          Builtins.y2milestone("Evaluating %1 as it was `next", result)
          result = :next
        end

        # Clients can break the installation/workflow
        Wizard.RestoreNextButton
        Wizard.RestoreAbortButton
        Wizard.RestoreBackButton

        # Remove file if step was run and returned (without a crash);
        if Ops.less_than(@current_step, Ops.subtract(Builtins.size(modules), 1)) &&
            !Stage.initial
          if !Convert.to_boolean(
            SCR.Execute(path(".target.remove"), Installation.current_step)
          )
            Builtins.y2error("Error removing step identifier")
          end
        end

        # Dont call debug hook scripts after installation is done. (#36831)
        if Ops.less_than(@current_step, Ops.subtract(Builtins.size(modules), 1)) &&
            !wasRun(step_name)
          DebugHooks.Run(step_name, false)
        else
          Builtins.y2milestone(
            "Not running debug hooks at the end of the installation"
          )
        end

        # This should be safe (#36831)
        DebugHooks.Checkpoint(step_name, false) # exit hook

        addToStack(step_name)

        if retranslate
          Builtins.y2milestone("retranslate")
          retranslateWizardDialog
          retranslate = false
        end

        # If the module return nil, something basic went wrong.
        # We show a stub dialog instead.
        if result.nil?
          # If workflow module is marked as optional, skip if it returns nil,
          # For example, if it is not installed.
          if Ops.get_boolean(step, "optional", false)
            Builtins.y2milestone(
              "Skipping optional %1",
              Builtins.symbolof(argterm)
            )
            @current_step = Ops.add(@current_step, 1)
            next
          end

          r = nil
          r = Popup.ModuleError(
            Builtins.sformat(
              # TRANSLATORS: an error message
              # this should not happen, but life is cruel...
              # %1 - (failed) module name
              # %2 - logfile, possibly with errors
              # %3 - link to our bugzilla
              # %4 - directory where YaST logs are stored
              # %5 - link to the Yast Bug Reporting HOWTO Web page
              "Calling the YaST module %1 has failed.\n" \
                "More information can be found near the end of the '%2' file.\n" \
                "\n" \
                "This is worth reporting a bug at %3.\n" \
                "Please, attach also all YaST logs stored in the '%4' directory.\n" \
                "See %5 for more information about YaST logs.",
              Builtins.symbolof(argterm),
              "/var/log/YaST2/y2log",
              "http://bugzilla.suse.com/",
              "/var/log/YaST2/",
              # link to the Yast Bug Reporting HOWTO
              # for translators: use the localized page for your language if it exists,
              # check the combo box "In other laguages" on top of the page
              _("http://en.opensuse.org/Bugs/YaST")
            )
          )

          if r == :next
            @current_step = Ops.add(@current_step, 1)
          elsif r == :back
            @current_step = Ops.subtract(@current_step, 1)
          elsif r != :again
            UI.CloseDialog
            return nil
          end
          next
        end

        # BNC #468677
        # The very first dialog must not exit with `back
        # or `auto
        if @current_step == 0 &&
            (result == :back || result == :auto && former_result == :back)
          Builtins.y2warning(
            "Returned %1, Current step %2 (%3). The current step will be called again...",
            result,
            @current_step,
            step_name
          )
          former_result = :next
          result = :again
        end

        if result == :next
          @current_step = Ops.add(@current_step, 1)
        elsif result == :back
          @current_step = Ops.subtract(@current_step, 1)
        elsif result == :cancel
          break
        elsif result == :abort
          # handling when user aborts the workflow (FATE #300422, bnc #406401, bnc #247552)
          final_result = result
          Hooks.run("installation_aborted")

          break
        elsif result == :finish
          break
        elsif result == :again
          next # Show same dialog again
        # BNC #475650: Adding `reboot_same_step
        elsif result == :restart_yast || result == :restart_same_step ||
            result == :reboot ||
            result == :reboot_same_step
          final_result = result
          break
        elsif result == :auto
          if !former_result.nil?
            if former_result == :next
              # if the first client just returns `auto, the back button
              # of the next client must be disabled
              if Ops.less_or_equal(@current_step, minimum_step) && !allow_back
                minimum_step = Ops.add(minimum_step, 1)
              end
              @current_step = Ops.add(@current_step, 1)
            elsif former_result == :back
              @current_step = Ops.subtract(@current_step, 1)
            end
          end
          next
        end
        former_result = result
      end

      final_result = :abort if former_result == :abort

      Builtins.y2milestone(
        "Former result: %1, Final result: %2",
        former_result,
        final_result
      )

      if !final_result.nil?
        Builtins.y2milestone("Final result already set.")
      elsif Ops.less_or_equal(@current_step, -1)
        final_result = :back
      else
        final_result = :next
      end

      Builtins.y2milestone(
        "Current step: %1, Returning: %2",
        @current_step,
        final_result
      )
      final_result
    end

    # Run Workflow
    #
    def Run
      ret = RunFrom(0, false)
      Builtins.y2milestone("Run() returning %1", ret)
      ret
    end

    # Functions to access restart information

    # List steps which were skipped since last restart of YaST
    # @return a list of maps describing the steps
    def SkippedSteps
      modules = getModules(Stage.stage, Mode.mode, :enabled)
      return nil if @first_step.nil?
      return nil if Ops.greater_or_equal(@first_step, Builtins.size(modules))
      index = 0
      ret = []
      while Ops.less_than(index, @first_step)
        ret = Builtins.add(ret, Ops.get(modules, index, {}))
        index = Ops.add(index, 1)
      end
      deep_copy(ret)
    end

    # Return step which restarted YaST (or rebooted the system)
    # @return a map describing the step
    def RestartingStep
      return nil if @restarting_step.nil?
      modules = getModules(Stage.stage, Mode.mode, :enabled)
      Ops.get(modules, @restarting_step, {})
    end

    # ProductControl Constructor
    # @return [void]
    def ProductControl
      Builtins.y2error("control file missing") if !Init()
      nil
    end

    # Sets additional params for selecting the workflow
    #
    # @param [Hash{String => Object}] params
    # @example SetAdditionalWorkflowParams ($["add_on_mode":"update"]);
    # @example SetAdditionalWorkflowParams ($["add_on_mode":"installation"]);
    def SetAdditionalWorkflowParams(params)
      params = deep_copy(params)
      Builtins.y2milestone(
        "Adjusting new additional workflow params: %1",
        params
      )

      @_additional_workflow_params = deep_copy(params)

      nil
    end

    # Resets all additional params for selecting the workflow
    # @see #SetAdditionalWorkflowParams()
    def ResetAdditionalWorkflowParams
      @_additional_workflow_params = {}

      nil
    end

    publish variable: :productControl, type: "map"
    publish variable: :workflows, type: "list <map>"
    publish variable: :proposals, type: "list <map>"
    publish variable: :inst_finish, type: "list <map <string, any>>"
    publish variable: :clone_modules, type: "list <string>"
    publish variable: :custom_control_file, type: "string"
    publish variable: :y2update_control_file, type: "string"
    publish variable: :default_control_file, type: "string"
    publish variable: :saved_control_file, type: "string"
    publish variable: :packaged_control_file, type: "string"
    publish variable: :current_control_file, type: "string"
    publish variable: :CurrentWizardStep, type: "string"
    publish variable: :last_stage_mode, type: "list <map>"
    publish variable: :logfiles, type: "list <string>"
    publish variable: :first_step, type: "integer"
    publish variable: :restarting_step, type: "integer"
    publish function: :CurrentStep, type: "integer ()"
    publish function: :setClientPrefix, type: "void (string)"
    publish function: :EnableModule, type: "list <string> (string)"
    publish function: :DisableModule, type: "list <string> (string)"
    publish function: :GetDisabledModules, type: "list <string> ()"
    publish function: :EnableProposal, type: "list <string> (string)"
    publish function: :DisableProposal, type: "list <string> (string)"
    publish function: :GetDisabledProposals, type: "list <string> ()"
    publish function: :EnableSubProposal, type: "map <string, list <string>> (string, string)"
    publish function: :DisableSubProposal, type: "map <string, list <string>> (string, string)"
    publish function: :GetDisabledSubProposals, type: "map <string, list <string>> ()"
    publish function: :checkDisabled, type: "boolean (map)"
    publish function: :checkHeading, type: "boolean (map)"
    publish function: :ReadControlFile, type: "boolean (string)"
    publish function: :checkArch, type: "boolean (map, map)"
    publish function: :getClientTerm, type: "term (map, map, any)"
    publish function: :getModeDefaults, type: "map (string, string)"
    publish function: :RequiredFiles, type: "list <string> (string, string)"
    publish function: :getCompleteWorkflow, type: "map (string, string)"
    publish function: :getModules, type: "list <map> (string, string, symbol)"
    publish function: :RunRequired, type: "boolean (string, string)"
    publish function: :getWorkflowLabel, type: "string (string, string, string)"
    publish function: :DisableAllModulesAndProposals, type: "void (string, string)"
    publish function: :UnDisableAllModulesAndProposals, type: "void (string, string)"
    publish function: :AddWizardSteps, type: "void (list <map>)"
    publish function: :UpdateWizardSteps, type: "void (list <map>)"
    publish function: :RetranslateWizardSteps, type: "void ()"
    publish function: :getProposals, type: "list <list> (string, string, string)"
    publish function: :getProposalTextDomain, type: "string ()"
    publish function: :getProposalProperties, type: "map (string, string, string)"
    publish function: :GetTranslatedText, type: "string (string)"
    publish function: :Init, type: "boolean ()"
    publish function: :wasRun, type: "boolean (string)"
    publish function: :RunFrom, type: "symbol (integer, boolean)"
    publish function: :Run, type: "symbol ()"
    publish function: :SkippedSteps, type: "list <map> ()"
    publish function: :RestartingStep, type: "map ()"
    publish function: :ProductControl, type: "void ()"
    publish function: :SetAdditionalWorkflowParams, type: "void (map <string, any>)"
    publish function: :ResetAdditionalWorkflowParams, type: "void ()"
  end

  ProductControl = ProductControlClass.new
  ProductControl.main
end
