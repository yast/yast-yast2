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

require "cwm"
require "abstract_method"

module CWM
  # Custom widget to manage multi status selection items
  #
  # It uses a RichText to emulate the multi selection list meeting following requirements:
  #
  #  - Allow to select more than one item.
  #  - Able to represent multiple statuses: no selected, selected, auto selected.
  #  - Items can be enable or disabled.
  #  - Emit different events to distinguish the interaction through check box input or its label.
  #  - Automatic text wrapping.
  #  - Keep the vertical scroll.
  #
  # If you want to see it in action, have a look at yast2-registration or yast2-packager modules.
  #
  # TODO: make possible to use it more than once in the same dialog, maybe by using the parent
  # widget_id as a prefix for the event_id. See {CWM::MultiStatusSelector#handle} and
  # {CWM::MultiStatusSelector::Item.event_id}.
  #
  # @example Defining a MultiStatusSelector to manage products selection (with dependencies)
  #
  #     require "cwm/multi_status_selector"
  #
  #     class MyMultiStatusSelector < CWM::MultiStatusSelector
  #       attr_reader :items
  #
  #       def initialize(products)
  #         @products = products
  #         @items = products.map { |p| Item.new(p) }
  #       end
  #
  #       def contents
  #         VBox(
  #           VWeight(60, super),
  #           VWeight(40, details)
  #         )
  #       end
  #
  #       def toggle(item)
  #         item.toggle
  #         select_dependencies
  #         label_event_handler(item)
  #       end
  #
  #       private
  #
  #       attr_accessor :products
  #
  #       def details
  #         @details ||= CWM::RichText.new
  #       end
  #
  #       def select_dependencies
  #         # logic to recalculate auto selected items
  #       end
  #
  #       def label_event_handler(item)
  #         details.value = item.description
  #       end
  #
  #       class Item < CWM::MultiStateSelector::Item
  #         attr_reader :status, :dependencies
  #
  #         def initialize(product)
  #           @product = product
  #           @status = product.status || UNSELECTED
  #           @dependencies = product.dependencies || []
  #         end
  #
  #         def id
  #           product.id
  #         end
  #
  #         def label
  #           product.friendly_name || product.name
  #         end
  #
  #         def description
  #           # build the item description
  #         end
  #
  #         private
  #
  #         attr_reader :product
  #       end
  #     end
  class MultiStatusSelector < CustomWidget
    # @!method items
    #   The items collection
    #   @return [Array<Item>] the collection of available items
    abstract_method :items

    # @macro seeAbstractWidget
    def init
      refresh
    end

    # @macro seeAbstractWidget
    def contents
      HBox(content)
    end

    # @macro seeAbstractWidget
    def handle(event)
      if event["ID"].to_s.include?(Item.event_id)
        id, fired_by = event["ID"].split(Item.event_id)

        item = find_item(id)
        send("#{fired_by}_event_handler", item)
      end

      nil
    end

    # Toggles the status of given item
    #
    # Redefine it if needed to perform additional actions before or after toggling the item, like
    # calculating dependencies for auto selection.
    #
    # @param item [Item] item to toggle the status
    def toggle(item)
      item.toggle
    end

  private

    # @macro seeAbstractWidget
    def handle_all_events
      true
    end

    # Handles the event fired by the Item check box input
    #
    # @param item [Item] the item that fired the event
    def input_event_handler(item)
      toggle(item)
      refresh
    end

    # Handles the event fired by the Item check box label
    #
    # @param [Item] the item that fired the event
    def label_event_handler(item)
      log.debug("Unhandled label event fired by #{item.inspect}")
    end

    # Returns the item with given id
    #
    # @param needle [#to_s] any object that responds to `#to_s`
    # @return [Item, nil] the item which id matches with given object#to_s
    def find_item(needle)
      items.find { |i| i.id.to_s == needle.to_s }
    end

    # Updates the content based on items list
    def refresh
      content.value = items.map(&:to_s).join("<br>")
    end

    # Convenience widget to keep the content updated
    #
    # @return [ContentArea]
    def content
      @content ||= Content.new
    end

    # A CWM::RichText able to keep the vertical scroll after updating its value
    class Content < RichText
      # @macro seeAbstractWidget
      def opt
        [:notify]
      end

      # @macro seeRichText
      def keep_scroll?
        true
      end
    end

    # A plain Ruby object in charge to build an item "check box" representation
    #
    # It already provides a default state (always enabled) and the logic to deal with the status
    # (selected, unselected or auto selected) but it can be extended by redefining the #status,
    # #toggle, and/or #enabled? methods.
    #
    # Derived classes must define #id and #label attributes/methods.
    #
    # See the {MultiStatusSelector} example.
    class Item
      extend Yast::I18n

      # Map to icons used in GUI to represent all the known statuses in both scenarios, during
      # installation (`inst` mode) and in a running system (`normal` mode).
      #
      # Available statuses are
      #
      #   - `[ ]` not selected
      #   - `[x]` selected
      #   - `[a]` auto-selected
      IMAGES = {
        "inst:[a]:enabled"    => "auto-selected.svg",
        "inst:[x]:enabled"    => "inst_checkbox-on.svg",
        "inst:[x]:disabled"   => "inst_checkbox-on-disabled.svg",
        "inst:[ ]:enabled"    => "inst_checkbox-off.svg",
        "inst:[ ]:disabled"   => "inst_checkbox-off-disabled.svg",
        "normal:[a]:enabled"  => "auto-selected.svg",
        "normal:[x]:enabled"  => "checkbox-on.svg",
        "normal:[ ]:enabled"  => "checkbox-off.svg",
        # NOTE: Normal theme has no special images for disabled check boxes
        "normal:[x]:disabled" => "checkbox-on.svg",
        "normal:[ ]:disabled" => "checkbox-off.svg"
      }.freeze
      private_constant :IMAGES

      # Path to the icons in the system
      IMAGES_DIR = "/usr/share/YaST2/theme/current/wizard".freeze
      private_constant :IMAGES_DIR

      # Selected status
      SELECTED = :selected
      private_constant :SELECTED

      # Not selected status
      UNSELECTED = :unselected
      private_constant :UNSELECTED

      # Auto selected status
      AUTO_SELECTED = :auto_selected
      private_constant :AUTO_SELECTED

      # Id to identify an event fired by the check box
      EVENT_ID = "#checkbox#".freeze
      private_constant :EVENT_ID

      # Id to identify an event fired by the check box input
      INPUT_EVENT_ID = "#{EVENT_ID}input".freeze
      private_constant :INPUT_EVENT_ID

      # Id to identify an event fired by the check box label
      LABEL_EVENT_ID = "#{EVENT_ID}label".freeze
      private_constant :LABEL_EVENT_ID

      textdomain "cwm"

      # @!method id
      #   The item id
      #   @return [#to_s]
      abstract_method :id

      # @!method label
      #   The item label
      #   @return [#to_s]
      abstract_method :label

      # @return [Symbol] the current item status
      attr_reader :status

      # Returns the common identifier of fired events
      #
      # @return [String] event identifier
      def self.event_id
        EVENT_ID
      end

      # Help text
      #
      # @return [String]
      def self.help
        help_text = "<p>"
        # TRANSLATORS: help text for a not selected check box
        help_text << "#{icon_for(UNSELECTED)} = #{_("Not selected")}<br />"
        # TRANSLATORS: help text for a selected check box
        help_text << "#{icon_for(SELECTED)} = #{_("Selected")}<br />"
        # TRANSLATORS: help text for an automatically selected check box
        # (it has a different look that a user selected check box)
        help_text << "#{icon_for(AUTO_SELECTED)} = #{_("Auto selected")}"
        help_text << "</p>"
        help_text
      end

      # Returns the icon to be used for an item with given status and state
      #
      # @see .value_for
      #
      # @param status [Symbol] the item status (e.g., :selected, :registered, :auto_selected)
      # @param mode [String] the running mode, "normal" or "inst"
      # @param state [String] the item state, "enabled" or "disabled"
      #
      # @return [String] an <img> tag when running in GUI mode; plain text otherwise
      def self.icon_for(status, mode: "normal", state: "enabled")
        value = value_for(status)

        if Yast::UI.TextMode
          value
        else
          # an image key looks like "inst:[a]:enabled"
          image_key = [mode, value, state].join(":")

          "<img src=\"#{IMAGES_DIR}/#{IMAGES[image_key]}\">"
        end
      end

      # Returns the status string representation
      #
      # @param status [Symbol] the status identifier
      #
      # @return [String] the status text representation
      def self.value_for(status)
        case status
        when SELECTED
          "[x]"
        when AUTO_SELECTED
          "[a]"
        else
          "[ ]"
        end
      end

      # Toggles the current status
      def toggle
        @status = selected? ? UNSELECTED : SELECTED
      end

      # Determines if the item is enabled or not
      #
      # @return [Boolean] true when item is enabled; false otherwise
      def enabled?
        true
      end

      # Whether item is selected
      #
      # @return [Boolean] true if the status is selected; false otherwise
      def selected?
        status == SELECTED
      end

      # Whether item is not selected
      #
      # @return [Boolean] true if the status is not selected; false otherwise
      def unselected?
        [SELECTED, AUTO_SELECTED].none?(status)
      end

      # Whether item is auto selected
      #
      # @return [Boolean] true if the status is auto selected; false otherwise
      def auto_selected?
        status == AUTO_SELECTED
      end

      # Sets the item as selected
      def select!
        @status = SELECTED
      end

      # Sets the item as not selected
      def unselect!
        @status = UNSELECTED
      end

      # Sets the item as auto-selected
      def auto_select!
        @status = AUTO_SELECTED
      end

      # Returns richtext representation for the item
      #
      # Basically, an string containing two <a> or <span> tags, depending on the #enabled? method.
      # One for the check box input and another for the label.
      #
      # @return [String] the item richtext representation
      def to_richtext
        "#{checkbox_input} #{checkbox_label}"
      end

    private

      # @see .icon_for
      def icon
        self.class.icon_for(status, mode: mode, state: state)
      end

      # Builds the check box input representation
      #
      # @return [String]
      def checkbox_input
        if enabled?
          "<a href=\"#{id}#{INPUT_EVENT_ID}\" style=\"#{text_style}\">#{icon}</a>"
        else
          "<span style\"#{text_style}\">#{icon}</a>"
        end
      end

      # Builds the check box label representation
      #
      # @return [String]
      def checkbox_label
        if enabled?
          "<a href=\"#{id}#{LABEL_EVENT_ID}\" style=\"#{text_style}\">#{label}</a>"
        else
          "<span style\"#{text_style}\">#{label}</a>"
        end
      end

      # Returns the current mode
      #
      # @return [String] "normal" in a running system; "inst" during the installation
      def mode
        installation? ? "inst" : "normal"
      end

      # Returns the current input state
      #
      # @return [String] "enabled" when item must be enabled; "disabled" otherwise
      def state
        enabled? ? "enabled" : "disabled"
      end

      # Returns style rules for the text
      #
      # @return [String] the status text representation
      def text_style
        "text-decoration: none; color: #{color}"
      end

      # Determines the color for the text
      #
      # @return [String] "grey" for a disabled item;
      #                  "white" when enabled and running in installation mode;
      #                  "black" otherwise
      def color
        return "grey" unless enabled?
        return "white" if installation?

        "black"
      end

      # Determines whether running in installation mode
      #
      # We do not use Stage.initial because of firstboot, which runs in 'installation' mode
      # but in 'firstboot' stage.
      #
      # @return [Boolean] Boolean if running in installation or update mode
      def installation?
        Yast::Mode.installation || Yast::Mode.update
      end
    end
  end
end
