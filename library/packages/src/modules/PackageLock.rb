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
# File:	modules/PackageLock.ycp
# Package:	yast2
# Summary:	Packages manipulation (system)
# Authors:	Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# This should be used everywhere before Pkg is first used. #160319
require "yast"

module Yast
  class PackageLockClass < Module
    def main
      Yast.import "Pkg"
      textdomain "base"

      Yast.import "Popup"
      Yast.import "Label"
      Yast.import "PackageKit"

      @have_lock = nil
      @aborted = false
      # display a different message in the first PackageKit quit confirmation
      @packagekit_asked = false
    end

    # Ask whether to quit PackageKit if it is running
    # @return [Boolean] true if PackageKit was asked to quit
    def AskPackageKit
      ret = false

      if PackageKit.IsRunning
        # ask to send quit signal to PackageKit
        msg = if @packagekit_asked
                _(
                  "PackageKit is still running (probably busy).\nAsk PackageKit to quit again?"
                )
        else
                _(
                  "PackageKit is blocking software management.\n" \
                    "This happens when the updater applet or another software management\n" \
                    "application is running.\n" \
                    "\n" \
                    "Ask PackageKit to quit?"
                )
        end

        @packagekit_asked = true

        if Popup.YesNo(msg)
          PackageKit.SuggestQuit
          ret = true
        end
      end

      ret
    end

    # Tries to acquire the packager (zypp) lock.
    # Reports an error if another process has the lock already.
    # Will only report once even if called multiple times.
    # @return true if we can continue
    def Check
      # we already have a lock
      return @have_lock if !@have_lock.nil?

      # just to allow 'Retry', see more in bug #280383
      try_again = true

      # while not having a lock and user wants to try again
      while try_again
        # Invoke a cheap call that accesses the zypp lock
        @have_lock = Pkg.Connect == true # nil guard
        break if @have_lock == true

        if @have_lock != true
          if AskPackageKit()
            # let the PackageKit quit before retrying
            Builtins.sleep(2000)
            next
          end

          try_again = Popup.AnyQuestion(
            # TRANSLATORS: a popup headline
            _("Accessing the Software Management Failed"),
            Ops.add(
              Ops.add(Pkg.LastError, "\n\n"),
              # TRANSLATORS: an error message with question
              _(
                "Would you like to continue without having access\nto the software management or retry to access it?\n"
              )
            ),
            Label.ContinueButton,
            Label.RetryButton,
            # 'Continue' instead of 'Retry'
            :focus_yes
          ) == false
        end

        Builtins.y2milestone("User decided to retry...") if try_again
      end

      Builtins.y2milestone("PackageLock::Check result: %1", @have_lock)
      @have_lock
    end

    # Tries to acquire the packager (zypp) lock.
    # Reports an error if another process has the lock already.
    # Will only report once even if called multiple times.
    # @param [Boolean] show_continue_button show option to continue without access
    # @return [Hash] with lock status and user reaction
    def Connect(show_continue_button)
      # we already have a lock
      if !@have_lock.nil?
        return { "connected" => @have_lock, "aborted" => @aborted }
      end

      try_again = true

      # while not having a lock and user wants to try again
      while try_again
        # Invoke a cheap call that accesses the zypp lock
        @have_lock = Pkg.Connect == true # nil guard
        break if @have_lock == true

        if @have_lock != true
          if AskPackageKit()
            # let the PackageKit quit before retrying
            Builtins.sleep(2000)
            next
          end

          if show_continue_button
            ret2 = Popup.AnyQuestion3(
              # TRANSLATORS: a popup headline
              _("Accessing the Software Management Failed"),
              Ops.add(
                Ops.add(Pkg.LastError, "\n\n"),
                # TRANSLATORS: an error message with question
                _(
                  "Would you like to retry accessing the software manager,\n" \
                    "continue without having access to the software management,\n" \
                    "or abort?\n"
                )
              ),
              Label.RetryButton,
              Label.ContinueButton,
              Label.AbortButton,
              # default is 'Retry'
              :focus_yes
            )

            try_again = ret2 == :yes

            # NOTE: due to the changed labels this actually means that [Abort] was pressed!!
            @aborted = true if ret2 == :retry
          else
            ret2 = Popup.AnyQuestion(
              # TRANSLATORS: a popup headline
              _("Accessing the Software Management Failed"),
              Ops.add(
                Ops.add(Pkg.LastError, "\n\n"),
                # TRANSLATORS: an error message with question
                _("Would you like to abort or try again?\n")
              ),
              Label.RetryButton,
              Label.AbortButton,
              # default is 'Retry'
              :focus_yes
            )

            try_again = ret2
            @aborted = !ret2
          end

          Builtins.y2milestone(
            "try_again: %1, aborted: %2",
            try_again,
            @aborted
          )
        end

        Builtins.y2milestone("User decided to retry...") if try_again
      end

      ret = { "connected" => @have_lock, "aborted" => @aborted }
      Builtins.y2milestone("PackageLock::Connect result: %1", ret)

      deep_copy(ret)
    end

    publish function: :Check, type: "boolean ()"
    publish function: :Connect, type: "map <string, any> (boolean)"
  end

  PackageLock = PackageLockClass.new
  PackageLock.main
end
