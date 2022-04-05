# ------------------------------------------------------------------------------
# Copyright (c) 2022 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# ------------------------------------------------------------------------------

require "yast2/system_time"
require "yast"

module Yast
  # Progress popup dialog that only opens after a certain delay, so it never
  # opens for very short operations (< 4 seconds by default), only when an
  # operation takes long enough to actually give feedback to the user.
  #
  # This is less disruptive than a progress dialog that always opens, and in
  # most cases, flashes by so fast that the user can't recognize what it says.
  #
  # The tradeoff is that it takes a few seconds until there is any visual
  # feedback (until the delay is expired).
  #
  # Notice that this does not use an active timer; the calling application has
  # to trigger the check for the timeout by calling progress() in regular
  # intervals.
  #
  # You can change the delay by changing the delay_seconds member variable, you
  # can force the dialog to open with open!, and you can stop and (re-) start
  # the timer.
  #
  # In any case, when done with this progress reporting, call close(). You
  # don't need to check if it ever opened; close() does that automatically.
  #
  # see   examples/delayed_progress_1.rb  for a usage example.
  #
  class DelayedProgressPopup
    include Yast::UIShortcuts
    include Yast::Logger

    # @return [String] Text for the dialog heading. Default: nil.
    attr_accessor :heading

    # @return [Integer] Delay (timeout) in seconds.
    attr_accessor :delay_seconds

    # @return [Integer] Percent (0..100) that are considered "almost done"
    # so the dialog is not opened anymore if it isn't already. Default: 80
    # Set this to 100 to disable that.
    attr_accessor :almost_done_percent

    # @return [Boolean] Add a "Cancel" button to the dialog. Default: true.
    attr_accessor :use_cancel_button

    # Constructor.
    #
    # If `auto_start` is `true` (default), this also starts the timer with a
    # default (4 seconds) timeout.
    #
    # The `close` method must be explicitly called at the end when the progress
    # is finished.
    #
    # @param delay [Integer,nil]  optional delay in seconds
    # @param auto_start [Boolean] start the timer immediately
    # @param heading [String,nil] optional popup heading
    def initialize(delay: nil, auto_start: true, heading: nil)
      Yast.import "UI"
      Yast.import "Label"

      @delay_seconds = delay || 4
      @heading = heading
      @use_cancel_button = true
      @almost_done_percent = 80
      @is_open = false
      start_timer if auto_start
      log.info "Created delayed progress popup"
    end

    # A static variant with block, it automatically closes the popup at the end.
    #
    # @param delay [Integer,nil] optional delay in seconds
    # @param heading [String,nil] optional popup heading
    # @example
    #  Yast::DelayedProgressPopup.run(delay: 5, heading: "Working...") do |popup|
    #    10.times do |sec|
    #      popup.progress(10 * sec, "Working #{sec}")
    #      sleep(1)
    #    end
    #  end
    def self.run(delay: nil, auto_start: true, heading: nil, &block)
      popup = new(delay: delay, auto_start: auto_start, heading: heading)
      block.call(popup)
    ensure
      popup&.close
    end

    # Update the progress.
    #
    # If the dialog is not open yet, this opens it if the timeout is expired;
    # unless the whole process is almost done anyway, i.e. at the time when the
    # dialog would be opened, progress_percent is already at the
    # @almost_done_percent threshold, so it would just open and then close
    # almost immediately again.
    #
    # @param [Integer] progress_percent  numeric progress bar value
    # @param [nil|String] progress_text  optional progress bar label text
    #
    def progress(progress_percent, progress_text = nil)
      log.info "progress_percent: #{progress_percent}"
      open_if_needed unless progress_percent >= @almost_done_percent
      return unless open?

      update_progress(progress_percent, progress_text)
    end

    # Open the dialog if needed, i.e. if it's not already open and if the timer
    # expired.
    #
    # Notice that progress() does this automatically.
    #
    def open_if_needed
      return if open?

      open! if timer_expired?
    end

    # Open the dialog unconditionally.
    def open!
      log.info "Opening the delayed progress popup"
      UI.OpenDialog(dialog_widgets)
      @is_open = true
      stop_timer
    end

    # Close the dialog if it is open. Only stop the timer if it is not (because
    # the timer didn't expire).
    #
    # Do not call this if another dialog was opened on top of this one in the
    # meantime: Just like a normal UI.CloseDialog call, this closes the topmost
    # dialog; which in that case might not be the right one.
    #
    def close
      stop_timer
      return unless open?

      UI.CloseDialog
      @is_open = false
    end

    # Start or restart the timer.
    def start_timer
      @start_time = Yast2::SystemTime.uptime
    end

    # Stop the timer.
    def stop_timer
      @start_time = nil
    end

    # Check if the dialog is open.
    def open?
      @is_open
    end

    # Check if the timer expired.
    def timer_expired?
      return false unless timer_running?

      now = Yast2::SystemTime.uptime
      now > @start_time + delay_seconds
    end

    # Check if the timer is running.
    def timer_running?
      !@start_time.nil?
    end

  protected

    # Return a widget term for the dialog widgets.
    # Reimplement this in inherited classes for a different dialog content.
    #
    def dialog_widgets
      placeholder_label = " " # at least one blank
      heading_spacing = @heading.nil? ? 0 : 0.4
      MinWidth(
        40,
        VBox(
          MarginBox(
            1, 0.4,
            VBox(
              dialog_heading,
              VSpacing(heading_spacing),
              VCenter(
                ProgressBar(Id(:progress_bar), placeholder_label, 100, 0)
              )
            )
          ),
          VSpacing(0.4),
          dialog_buttons
        )
      )
    end

    # Return a widget term for the dialog heading.
    def dialog_heading
      return Empty() if @heading.nil?

      Left(Heading(@heading))
    end

    # Return a widget term for the dialog buttons.
    # Reimplement this in inherited classes for different buttons.
    #
    # Notice that the buttons only do anything if the calling application
    # handles them, e.g. with UI.PollInput().
    #
    # Don't forget that in the Qt UI, every window has a WM_CLOSE button (the
    # [x] icon in the window title bar that is meant for closing the window)
    # that returns :cancel in UI.UserInput() / UI.PollInput().
    #
    def dialog_buttons
      return Empty() unless @use_cancel_button

      ButtonBox(
        PushButton(Id(:cancel), Opt(:cancelButton), Yast::Label.CancelButton)
      )
    end

    # Update the progress bar.
    def update_progress(progress_percent, progress_text = nil)
      return unless UI.WidgetExists(:progress_bar)

      UI.ChangeWidget(Id(:progress_bar), :Value, progress_percent)
      UI.ChangeWidget(Id(:progress_bar), :Label, progress_text) unless progress_text.nil?
    end
  end
end
