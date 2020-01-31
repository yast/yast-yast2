# Copyright (c) [2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "abstract_method"
require "cwm/progress_bar"

module CWM
  # Widget for a dynamic progress bar, where the label can be set for every step.
  #
  # This progress bar is useful when steps are not known in advance or part of them are dynamically
  # generated.
  #
  # @example
  #
  #   class MyProgressBar < CWM::DynamicProgessBar
  #     def steps_count
  #       3
  #     end
  #
  #     def label
  #       "Progress"
  #     end
  #   end
  #
  #   pg = MyProgressBar.new
  #
  #   pg.forward("step 1") #=> shows label "step 1"
  #   pg.forward           #=> shows label "Progress"
  #   pg.forward("step 3") #=> shows label "step 3"
  class DynamicProgressBar < ProgressBar
    # Moves the progress forward and sets the given step as label
    #
    # @see ProgressBar#forward
    def forward(step = nil)
      next_step(step) if step

      super()
    end

    # @!method label
    #
    #   Label for the progress bar when no step is given, see {#forward}.
    #
    #   @return [String]
    abstract_method :label

    # @!method steps_count
    #
    #   Number of steps
    #
    #   @return [Integer]
    abstract_method :steps_count

  private

    # @see ProgressBar#steps
    def steps
      @steps ||= [label] * steps_count
    end

    # Sets the label for the next step
    #
    # @param step [String]
    def next_step(step)
      return if complete?

      steps[current_step_index + 1] = step
    end
  end
end
