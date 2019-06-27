# Copyright (c) [2018] SUSE LLC
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

module CWM
  # Singleton class to keep the position of the user in the UI and other similar
  # information that needs to be rememberd across UI redraws to give the user a
  # sense of continuity.
  #
  # If you want to see it in action, have a look at yast2-storage-ng or yast2-firewall
  # modules.
  #
  # @example Defining a UIState class to handle firewall zones (extracted from yast2-firewall)
  #
  #   require "cwm/ui_state"
  #   class MyUIState < CWM::UIState
  #     def go_to_tree_node(page)
  #       super
  #       self.candidate_notes =
  #         if page.respond_to?(:zone)
  #           zone_page_candidates(page)
  #         else
  #           [page.label]
  #         end
  #       end
  #     end
  #
  #   private
  #
  #     def zone_page_candidates(page)
  #       [page.zone.name]
  #     end
  #   end
  #
  # @example Using the UIState from an CWM::TreePager
  #
  #   class OverviewTreePager < CWM::TreePager
  #     # Overrides default behaviour to register the new state.
  #     def switch_page(page)
  #       MyUIState.instance.go_to_tree_node(page)
  #       super
  #     end
  #
  #     # Ensures the tree is properly initialized according to the UI state after
  #     # a redraw
  #     def initial_page
  #       MyUIState.instance.find_tree_node(@pages) || super
  #     end
  #   end
  #
  # @example Registering the selected row from a CWM::Table
  #
  #   class MyTable < ::CWM::Table
  #     def opt
  #       [:notify, :immediate]
  #     end
  #
  #     def handle(event)
  #       MyUIState.instance.select_row(value) if event["EventReason"] == "SelectionChanged"
  #       nil
  #     end
  #   end
  #
  class UIState
    include Yast::I18n

    # Constructor
    #
    # Called through {.create_instance}, starts with a blank situation (which
    # means default for each widget will be honored).
    def initialize
      @candidate_nodes = []
    end

    # Method to be called when the user decides to visit a given page by
    # clicking in one node of the general tree.
    #
    # It remembers the decision so the user is taken back to a sensible point of
    # the tree (very often the last he decided to visit) after redrawing.
    #
    # @param [CWM::Page] page associated to the tree node
    def go_to_tree_node(page)
      self.candidate_nodes = [page.label]

      # Landing in a new node, so invalidate previous details about position
      # within a node, they no longer apply
      self.tab = nil
    end

    # Method to be called when the user switches to a tab within a tree node.
    #
    # It remembers the decision so the same tab is showed in case the user stays
    # in the same node after redrawing.
    #
    # @param [CWM::Page] page associated to the tab
    def switch_to_tab(page)
      self.tab = page.label
    end

    # Method to be called when the user operates in a row of a table.
    #
    # @param row_id [Object] row identifier
    def select_row(row_id)
      self.row_id = row_id
    end

    # Select the page to open in the general tree after a redraw
    #
    # @param pages [Array<CWM::Page>] all the pages in the tree
    # @return [CWM::Page, nil]
    def find_tree_node(pages)
      candidate_nodes.each.with_index do |candidate, idx|
        result = pages.find { |page| matches?(page, candidate) }
        if result
          # If we had to use one of the fallbacks, the tab name is not longer
          # trustworthy
          self.tab = nil unless idx.zero?
          return result
        end
      end
      self.tab = nil
      nil
    end

    # Select the tab to open within the node after a redraw
    #
    # @param pages [Array<CWM::Page>] pages for all the possible tabs
    # @return [CWM::Page, nil]
    def find_tab(pages)
      return nil unless tab

      pages.find { |page| page.label == tab }
    end

    # @!attribute [r] row_id
    #   @return [Object] Selected row identifier
    # @see #row_id
    attr_reader :row_id

  protected

    attr_writer :row_id

    # Where to place the user within the general tree in next redraw
    # @return [Array<Integer, String>]
    attr_accessor :candidate_nodes

    # Concrete tab within the current node to show in the next redraw
    # @return [String, nil]
    attr_reader :tab
    # @see #tab
    def tab=(tab)
      @tab = tab
      # If the user switched to a new tab, invalidate details about the inner
      # table
      self.row_id = nil
    end

    # Whether the given page matches with the candidate tree node
    #
    # @param page [CWM::Page]
    # @param candidate [Integer, String]
    # @return boolean
    def matches?(page, candidate)
      page.label == candidate
    end

    class << self
      # Singleton instance
      def instance
        create_instance unless @instance
        @instance
      end

      # Enforce a new clean instance
      def create_instance
        @instance = new
      end

      # Make sure only .instance and .create_instance can be used to
      # create objects
      private :new, :allocate
    end
  end
end
