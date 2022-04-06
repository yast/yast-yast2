# Example for the DelayedProgressPopup
#
# Start with:
#
#   y2start ./delayed_progress_almost_done.rb qt
# or
#   y2start ./delayed_progress_almost_done.rb ncurses
#

require "yast"
require "ui/delayed_progress_popup"

Yast::DelayedProgressPopup.run(delay: 3, heading: "Deep Think Mode") do |popup|
  # All those parameters are optional;
  # comment out or uncomment to experiment.
  # popup.heading = "Deep Think Mode"
  # popup.use_cancel_button = false

  puts("This will never open, not even after the #{popup.delay_seconds} sec delay.")

  5.times do |sec|
    percent = 80 + sec
    puts "#{sec} sec; progress: #{percent}%"
    popup.progress(percent, "Working #{sec}")
    if popup.open?
      # Checking for popup.open? is only needed here because otherwise there is
      # no window at all yet, so UI.WaitForEvent() throws an exception. Normal
      # applications have a main window at this point.

      event = Yast::UI.WaitForEvent(1000) # implicitly sleeps
      break if event["ID"] == :cancel
    else
      sleep(1)
    end
  end
end
