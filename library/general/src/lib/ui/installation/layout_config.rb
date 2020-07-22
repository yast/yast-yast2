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

require "yast"

module UI
  module Installation
    # Configuration for a installation layout
    class LayoutConfig
      Yast.import "ProductFeatures"

      module Mode
        STEPS = :steps
        TITLE_ON_LEFT = :title_on_left
        TITLE_ON_TOP = :title_on_top
      end

      # @return [Mode] Layout mode
      attr_accessor :mode

      # @return [Boolean] Whether to use a banner
      attr_accessor :banner

      # Creates a new configuration with values from product features
      #
      # @see .load_product_features
      #
      # @return [LayoutConfig]
      def self.from_product_features
        new.load_product_features
      end

      # Constructor
      #
      # By default, the layout is created with title on top and without banner.
      def initialize
        @mode = Mode::TITLE_ON_TOP
        @banner = false
      end

      # Sets the mode and banner according to the product features.
      #
      # Normally, the product features take the layout seetings from the globals section of a control
      # file, for example:
      #
      #   <globals>
      #     <installation_ui>sidebar</installation_ui>
      #     <installation_layout>
      #       <mode>steps</mode>
      #       <banner>true</banner
      #     </installation_layout>
      #   </globals>
      #
      # Note that installation_ui is deprecated in favor of installation_layout. In fact,
      # installation_layout gets precedence.
      #
      # @return [LayoutConfig]
      def load_product_features
        if installation_layout && !installation_layout.empty?
          self.mode = installation_layout[:mode] unless installation_layout[:mode].nil?
          self.banner = installation_layout[:banner] unless installation_layout[:banner].nil?
        elsif installation_ui == "sidebar"
          self.mode = Mode::STEPS
          self.banner = false
        else
          # Current default values when nothing is indicated in the control file
          self.mode = Mode::TITLE_ON_LEFT
          self.banner = true
        end

        self
      end

    private

      # Returns the value for the installation_ui setting from the product features
      #
      # This setting is only meaningful when its value is "sidebar". In that case, the layout should be
      # configured with the sidebar and without banner. See {#load_product_features}.
      #
      # Note that installation_ui is deprecated in favor of installation_layout.
      #
      # @return [String, nil]
      def installation_ui
        @installation_ui ||= Yast::ProductFeatures.GetFeature("globals", "installation_ui")
      end

      # Returns the values for the installation_layout setting from the product features
      #
      # @return [nil, Hash{Symbol => Symbol, Boolean}] e.g., { mode: Mode::STEPS, banner: true}. Returns
      #   nil when no settings are indicated for installation_layout.
      def installation_layout
        return @installation_layout unless @installation_layout.nil?

        installation_layout = Yast::ProductFeatures.GetFeature("globals", "installation_layout")

        return nil unless installation_layout.is_a?(Hash)

        @installation_layout = {}

        @installation_layout[:mode] =
          case installation_layout["mode"]
          when "steps"
            Mode::STEPS
          when "title-on-left"
            Mode::TITLE_ON_LEFT
          when "title-on-top"
            Mode::TITLE_ON_TOP
          end

        @installation_layout[:banner] = !!installation_layout["banner"]

        @installation_layout
      end
    end
  end
end
