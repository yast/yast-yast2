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
require "ui/installation/layout_config"

module UI
  module Installation
    # Class to define the wizard layout for the installation
    #
    # There are three possible layouts:
    #
    # * With a left sidebar to place the installation steps.
    # * Without a sidebar but with the title of the dialogs on the left.
    # * Without a sidebar but with the title of the dialogs on top.
    #
    # Moreover, for each layout, a top banner can be added.
    #
    # @example
    #   layout1 = UI::Installation::Layout.with_steps
    #   layout2 = UI::Installation::Layout.with_title_on_left
    #   layout3 = UI::Installation::Layout.with_title_on_top
    #
    #   layout3.show_banner
    #
    #   layout1.open_wizard do
    #     # ...
    #   end
    class Layout
      Yast.import "UI"
      Yast.import "Wizard"

      class << self
        # Creates a new layout with a left sidebar to place the installation steps
        #
        # @return [Layout]
        def with_steps
          config = LayoutConfig.new.tap { |c| c.mode = LayoutConfig::Mode::STEPS }

          new(config)
        end

        # Creates a new layout with without a sidebar but with the title of the dialogs on the left
        #
        # @return Layout]
        def with_title_on_left
          config = LayoutConfig.new.tap { |c| c.mode = LayoutConfig::Mode::TITLE_ON_LEFT }

          new(config)
        end

        # Creates a new layout with without a sidebar but with the title of the dialogs on top
        #
        # @return [Layout]
        def with_title_on_top
          config = LayoutConfig.new.tap { |c| c.mode = LayoutConfig::Mode::TITLE_ON_TOP }

          new(config)
        end

        # Creates a new layout according to the product features
        #
        # @see LayoutConfig.from_product_features
        #
        # @return [Layout]
        def from_product_features
          config = LayoutConfig.from_product_features

          new(config)
        end
      end

      # Configures the layout to show a banner
      def show_banner
        config.banner = true
      end

      # Configures the layout to not show a banner
      def hide_banner
        config.banner = false
      end

      # Whether the layout includes a banner
      #
      # @return [Boolean]
      def banner?
        config.banner
      end

      # Whether the layout has a left sidebar to place the installation steps
      #
      # @return [Boolean]
      def with_steps?
        config.mode == LayoutConfig::Mode::STEPS
      end

      # Whether the layout has the title of the dialogs on the left
      #
      # @return [Boolean]
      def with_title_on_left?
        config.mode == LayoutConfig::Mode::TITLE_ON_LEFT
      end

      # Whether the layout has the title of the dialogs on the top
      #
      # @return [Boolean]
      def with_title_on_top?
        config.mode == LayoutConfig::Mode::TITLE_ON_TOP
      end

      # Opens a new wizard according to the layout configuration
      #
      # @yield Code to run after opening the wizard. The wizard is automatically closed.
      def open_wizard(&block)
        Yast::UI.SetProductLogo(banner?)

        case config.mode
        when LayoutConfig::Mode::STEPS
          Yast::Wizard.OpenNextBackStepsDialog
        when LayoutConfig::Mode::TITLE_ON_LEFT
          Yast::Wizard.OpenLeftTitleNextBackDialog
        else
          Yast::Wizard.OpenNextBackDialog
        end

        return unless block_given?

        block.call
        close_wizard
      end

      # Closes the wizard
      def close_wizard
        Yast::Wizard.CloseDialog
      end

    private

      # @return LayoutConfig
      attr_reader :config

      # Constructor
      #
      # @param [Layout, nil] Layout configuration
      def initialize(config = nil)
        @config = config || LayoutConfig.new
      end
    end
  end
end
