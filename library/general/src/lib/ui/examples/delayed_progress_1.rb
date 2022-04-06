# Example for the DelayedProgressPopup
#
# Start with:
#
#   y2start ./delayed_progress_1.rb qt
# or
#   y2start ./delayed_progress_1.rb ncurses
#

require "yast"
require "ui/delayed_progress_popup"

popup = Yast::DelayedProgressPopup.new

# All those parameters are optional;
# comment out or uncomment to experiment.
popup.heading = "Deep Think Mode"
popup.delay_seconds = 2
# popup.use_cancel_button = false

puts("Nothing happens for #{popup.delay_seconds} seconds, then the popup opens.")

10.times do |sec|
  puts "#{sec} sec"
  popup.progress(10 * sec, "Working #{sec}")
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
popup.close
