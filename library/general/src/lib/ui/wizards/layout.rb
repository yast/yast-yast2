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
  module Wizards
    # Class to configure a wizard layout
    #
    # There are four possible layouts:
    #
    # * With a left sidebar which is usually used to place the installation steps.
    # * With a left tree.
    # * Without a sidebar/tree and with the title of the dialogs on the left.
    # * Without a sidebar/tree and with the title of the dialogs on top.
    #
    # Moreover, for each layout, a top banner can be added.
    #
    # @example
    #   layout1 = UI::Wizards::Layout.with_steps
    #   layout2 = UI::Wizards::Layout.with_title_on_left
    #   layout3 = UI::Wizards::Layout.with_title_on_top
    #
    #   layout3.show_banner
    #
    #   layout1.open_wizard do
    #     # ...
    #   end
    class Layout
      Yast.import "Wizard"
      Yast.import "ProductFeatures"

      # Class to represent a layout mode
      class Mode
        STEPS = :steps
        TREE = :tree
        TITLE_ON_LEFT = :title_on_left
        TITLE_ON_TOP = :title_on_top

        private_constant :STEPS, :TREE, :TITLE_ON_LEFT, :TITLE_ON_TOP

        class << self
          # Mode for a layout with a left sidebar
          #
          # @return [Mode]
          def steps
            new(STEPS)
          end

          # Mode for a layout with a left tree
          #
          # @return [Mode]
          def tree
            new(TREE)
          end

          # Mode for a layout without a sidebar/tree and with the title of the dialogs on the left
          #
          # @return [Mode]
          def title_on_left
            new(TITLE_ON_LEFT)
          end

          # Mode for a layout without a sidebar/tree and with the title of the dialogs on top
          #
          # @return [Mode]
          def title_on_top
            new(TITLE_ON_TOP)
          end
        end

        # Whether the layout mode is for steps
        #
        # @return [Boolean]
        def steps?
          @mode == STEPS
        end

        # Whether the layout mode is for a tree
        #
        # @return [Boolean]
        def tree?
          @mode == TREE
        end

        # Whether the layout mode for title on left
        #
        # @return [Boolean]
        def title_on_left?
          @mode == TITLE_ON_LEFT
        end

        # Whether the layout mode is for title on top
        #
        # @return [Boolean]
        def title_on_top?
          @mode == TITLE_ON_TOP
        end

      private

        # Constructor
        #
        # @param Mode [Symbol]
        def initialize(mode)
          @mode = mode
        end
      end

      class << self
        # Creates a new layout with a left sidebar
        #
        # @return [Layout]
        def with_steps
          new(Mode.steps)
        end

        # Creates a new layout with a left tree
        #
        # @return [Layout]
        def with_tree
          new(Mode.tree)
        end

        # Creates a new layout without a sidebar/tree and with the title of the dialogs on the left
        #
        # @return Layout]
        def with_title_on_left
          new(Mode.title_on_left)
        end

        # Creates a new layout without a sidebar/tree and with the title of the dialogs on top
        #
        # @return [Layout]
        def with_title_on_top
          new(Mode.title_on_top)
        end

        # Creates a new layout according to the product features
        #
        # @return [Layout]
        def from_product_features
          new.send(:load_product_features)
        end
      end

      # Layout mode
      #
      # @return [Mode]
      attr_reader :mode

      # Configures the layout to show a banner
      def show_banner
        @banner = true
      end

      # Configures the layout to not show a banner
      def hide_banner
        @banner = false
      end

      # Whether the layout includes a banner
      #
      # @return [Boolean]
      def banner?
        @banner
      end

      # Opens a new wizard according to the layout configuration
      #
      # @yield Code to run after opening the wizard. The wizard is automatically closed.
      def open_wizard(&block)
        Yast::Wizard.OpenWithLayout(self)

        return unless block_given?

        block.call
        close_wizard
      end

      # Closes the wizard
      def close_wizard
        Yast::Wizard.CloseDialog
      end

    private

      # Constructor
      #
      # @param mode [Mode] layout mode
      def initialize(mode = Mode.title_on_top)
        @mode = mode
        @banner = false
      end

      # Configures the layout according to the product features.
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
      # installation_layout takes precedence.
      #
      # @return [Layout]
      def load_product_features
        if installation_layout && !installation_layout.empty?
          @mode = installation_layout[:mode] unless installation_layout[:mode].nil?
          @banner = installation_layout[:banner] unless installation_layout[:banner].nil?
        elsif installation_ui == "sidebar"
          @mode = Mode.steps
          @banner = false
        else
          # Current default values when nothing is indicated in the control file
          @mode = Mode.title_on_left
          @banner = true
        end

        self
      end

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
      # @return [nil, Hash{Symbol => Mode, Boolean, nil}] e.g., { mode: Mode.steps, banner: true}.
      #   Returns nil when no settings are indicated for installation_layout.
      def installation_layout
        return @installation_layout unless @installation_layout.nil?

        installation_layout = Yast::ProductFeatures.GetFeature("globals", "installation_layout")

        return nil unless installation_layout.is_a?(Hash)

        @installation_layout = {}

        @installation_layout[:mode] =
          case installation_layout["mode"]
          when "steps"
            Mode.steps
          when "title-on-left"
            Mode.title_on_left
          when "title-on-top"
            Mode.title_on_top
          end

        @installation_layout[:banner] = installation_layout["banner"]

        @installation_layout
      end
    end
  end
end
