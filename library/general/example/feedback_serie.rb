# typed: strict
require "yast"

require "yast2/feedback"

Yast2::Feedback.show("feedback for time consuming operation", headline: "Syncing file1 ...") do |feedback|
  sleep(5)
  feedback.update("And now another time consuming operation", headline: "Syncing file2 ...")
  sleep(5)
end

feedback = Yast2::Feedback.new
feedback.start("File1")
sleep(5)
feedback.update("File2")
sleep(5)
feedback.stop
