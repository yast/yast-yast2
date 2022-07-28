# ------------------------------------------------------------------------------
# Copyright (c) 2016-2022 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------
#

require "yast"
require "ui/delayed_progress_popup"

module Packages
  # Default file conflicts callbacks for package bindings. To register the
  # callbacks in Yast::Pkg just call {Packages::FileConflictCallbacks.register}
  class FileConflictCallbacks
    class << self
      include Yast::Logger
      include Yast::I18n
      include Yast::UIShortcuts

      # register the file conflict callbacks
      def register
        Yast.import "Pkg"
        Yast.import "UI"
        Yast.import "Progress"
        Yast.import "Mode"
        Yast.import "CommandLine"
        Yast.import "Report"
        Yast.import "Label"
        Yast.import "PackageCallbacks"
        Yast.import "Wizard"

        textdomain "base"

        create_delayed_progress_popup unless Yast::Mode.commandline
        register_file_conflict_callbacks
      end

    private

      # Helper function for creating a YaST function reference
      def fun_ref(*args)
        Yast::FunRef.new(*args)
      end

      # Register the default file conflicts callbacks
      def register_file_conflict_callbacks
        log.info "Registering file conflict callbacks"

        Yast::Pkg.CallbackFileConflictStart(fun_ref(method(:start), "void ()"))
        Yast::Pkg.CallbackFileConflictProgress(fun_ref(method(:progress),
          "boolean (integer)"))
        Yast::Pkg.CallbackFileConflictReport(fun_ref(method(:report),
          "boolean (list<string>, list<string>)"))
        Yast::Pkg.CallbackFileConflictFinish(fun_ref(method(:finish), "void ()"))

        nil
      end

      # Create the DelayedProgressPopup, but don't start the timer yet.
      #
      # This needs to be done outside of any of the callbacks to avoid clashes
      # between Ruby, C++ and ex-YCP YaST components.
      #
      # rubocop:disable Style/ClassVars
      def create_delayed_progress_popup
        log.info "Creating DelayedProgressPopup"
        @@delayed_progress_popup ||= Yast::DelayedProgressPopup.new(
          auto_start: false,
          heading:    progress_bar_label
        )
        nil
      end

      def delayed_progress_popup
        # Intentionally NOT creating the DelayedProgressPopup here so it isn't
        # accidentially created in one of the callbacks.
        @@delayed_progress_popup
      end
      # rubocop:enable Style/ClassVars

      def progress_bar_label
        # TRANSLATORS: progress bar label
        _("Checking file conflicts...")
      end

      # Set the label text of the global progress bar, if it exists.
      #
      # @param [String] text
      #
      def update_progress_text(text)
        # This uses the widget ID of the global progress bar of the SlideShow
        # module directly to keep the cross-dependencies down at least a little
        # bit.
        #
        # On the plus side, this is so defensive (it does nothing if there is
        # no such widget) that the worst thing that can happen is that there is
        # that there is no immediate feedback by setting the progress bar label.
        return unless Yast::UI.WidgetExists(:progressTotal)

        Yast::UI.ChangeWidget(:progressTotal, :Label, text)
      end

      # Handle the file conflict detection start callback.
      def start
        log.info "Starting the file conflict check..."

        if Yast::Mode.commandline
          Yast::CommandLine.PrintVerbose(progress_bar_label)
        else
          # Don't create the DelayedProgressPopup here, otherwise there will be
          # conflicts between the Ruby, C++ and ex-YCP YaST components.
          delayed_progress_popup.start_timer
          update_progress_text(progress_bar_label) # Immediate feedback
        end
      end

      # Handle the file conflict detection progress callback.
      # @param [Fixnum] progress progress in percents
      # @return [Boolean] true = continue, false = abort
      def progress(progress)
        log.debug "File conflict progress: #{progress}%"

        if Yast::Mode.commandline
          Yast::CommandLine.PrintVerboseNoCR("#{Yast::PackageCallbacksClass::CLEAR_PROGRESS_TEXT}#{progress}%")
          return true
        end

        delayed_progress_popup.progress(progress)
        return true unless delayed_progress_popup.open?

        ui = Yast::UI.PollInput
        log.info "User input in file conflict progress (#{progress}%): #{ui}"

        ui != :abort && ui != :cancel
      end

      # Handle the file conflict detection result callback.
      # Ask the user whether to continue. In AutoYaST mode, an error is
      # reported, but the installation will continue ignoring the conflicts.
      #
      # @param excluded_packages [Array<String>] packages ignored in the check
      #   (e.g. not available for check in the download-as-needed mode)
      # @param conflicts [Array<String>] list of translated descriptions of
      #   the detected file conflicts
      # @return [Boolean] true = continue, false = abort
      #
      def report(excluded_packages, conflicts)
        log.info "Excluded #{excluded_packages.size} packages in file conflict check"
        log.debug "Excluded packages: #{excluded_packages.inspect}"
        log.info "Found #{conflicts.size} conflicts: #{conflicts.join("\n\n")}"

        # just continue installing packages if there is no conflict
        return true if conflicts.empty?

        # don't ask in autoyast or command line mode, just report/log the issues and continue
        if Yast::Mode.auto || Yast::Mode.commandline
          # TRANSLATORS: An error message, %s is the actual list of detected conflicts
          Yast::Report.Error(_("File conflicts detected, these conflicting files will " \
                               "be overwritten:\n\n%s") % conflicts.join("\n\n"))
          return true
        end

        Yast::UI.OpenDialog(dialog(conflicts))

        begin
          ret = Yast::UI.UserInput
          log.info "User Input: #{ret}"
          ret == :continue
        ensure
          Yast::UI.CloseDialog
        end
      end

      # Handle the file conflict detection finish callback.
      def finish
        log.info "File conflict check finished"
        return if Yast::Mode.commandline

        delayed_progress_popup.close
        update_progress_text(" ") # One blank to maintain the label's height
      end

      # Construct the file conflicts dialog.
      # @param [Array<String>] conflicts file conflicts reported by libzypp
      #   (in human readable form)
      # @return [Term] UI term
      def dialog(conflicts)
        button_box = ButtonBox(
          PushButton(Id(:continue), Opt(:okButton), Yast::Label.ContinueButton),
          PushButton(Id(:abort), Opt(:default, :cancelButton), Yast::Label.AbortButton)
        )

        # TRANSLATORS: A popup label, use max. 70 chars per line, use more lines if needed
        label = _("File conflicts happen when two packages attempt to install\n" \
                  "files with the same name but different contents. If you continue\n" \
                  "the conflicting files will be replaced, losing the previous content.")

        # TRANSLATORS: Popup heading
        heading = n_("A File Conflict Detected", "File Conflicts Detected", conflicts.size)

        VBox(
          Left(Heading(heading)),
          VSpacing(0.2),
          Left(Label(label)),
          MinSize(65, 15, RichText(Opt(:plainText), conflicts.join("\n\n"))),
          button_box
        )
      end
    end
  end
end
