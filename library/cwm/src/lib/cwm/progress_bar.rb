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
require "cwm/custom_widget"

module CWM
  # Widget for a progress bar
  #
  # @example
  #
  #   class MyProgressBar < CWM::ProgessBar
  #     def steps
  #       ["step 1", "step 2", "step 3"]
  #     end
  #   end
  #
  #   pg = MyProgressBar.new
  #
  #   pg.forward #=> shows label "step 1"
  #   pg.forward #=> shows label "step 2"
  #   pg.forward #=> shows label "step 3"
  class ProgressBar < CustomWidget
    # Constructor
    def initialize
      super

      @current_step_index = 0
    end

    # @see CWM::CustomWidget#contents
    def contents
      ProgressBar(Id(widget_id), current_label, total_steps, current_step_index)
    end

    # Moves the progress forward and sets the next step as label if needed (see #show_steps?)
    def forward
      return if complete?

      @current_step_index += 1

      refresh
    end

    # @!method steps
    #
    #   Steps for the progress bar
    #
    #   @return [Array<String>]
    abstract_method :steps

  private

    # Index to the current step
    #
    # @return [Integer]
    attr_reader :current_step_index

    # Whether the steps should be used for the label of the progress bar
    #
    # @return [Boolean] if false, no label is shown
    def show_steps?
      true
    end

    # Total number of steps
    #
    # @return [Integer]
    def total_steps
      steps.size
    end

    # Label to use for the current step
    #
    # @see {#show_steps?}
    #
    # @return [String]
    def current_label
      label = show_steps? ? current_step : nil

      label || ""
    end

    # Current step
    #
    # @return [String]
    def current_step
      steps[current_step_index]
    end

    # Whether the progress bar is already complete
    #
    # @return [Boolean]
    def complete?
      current_step_index == total_steps
    end

    # Refreshes the progress bar according to the current step
    def refresh
      Yast::UI.ChangeWidget(Id(widget_id), :Value, current_step_index)
      Yast::UI.ChangeWidget(Id(widget_id), :Label, current_label)
    end
  end
end
