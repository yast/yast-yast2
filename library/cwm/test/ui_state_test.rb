#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require_relative "test_helper"
require "cwm/ui_state"

describe CWM::UIState do
  class MyUIState < CWM::UIState
    def textdomain_name
      "base"
    end
  end
  subject(:ui_state) { MyUIState.instance }

  describe ".new" do
    it "cannot be used directly" do
      expect { MyUIState.new }.to raise_error(/private method/)
    end
  end

  describe ".instance" do
    it "returns the singleton object in subsequent calls" do
      initial = MyUIState.create_instance
      second = MyUIState.instance
      # Note using equal to ensure is actually the same object (same object_id)
      expect(second).to equal initial
      expect(MyUIState.instance).to equal initial
    end
  end

  describe ".create_instance" do
    it "returns a new singleton UIState object" do
      initial = MyUIState.instance
      result = MyUIState.create_instance
      expect(result).to be_a MyUIState
      expect(result).to_not equal initial
    end
  end

  describe "#find_tree_node" do
    let(:pager) { double("TreePager") }
    let(:page1) { double("Page", label: "Page 1") }
    let(:page2) { double("Page", label: "Page 2") }

    let(:pages) { [page1, page2] }

    context "if the user has still not visited any node" do
      before { MyUIState.create_instance }

      it "returns nil" do
        expect(ui_state.find_tree_node(pages)).to be_nil
      end
    end

    context "when the user has opened a page" do
      before { ui_state.go_to_tree_node(page2) }

      context "if the page is still there after redrawing" do

        it "selects the previously selected page" do
          expect(ui_state.find_tree_node(pages)).to eq page2
        end
      end

      context "if the page is not longer there after redrawing" do
        before do
          pages.clear
          pages.concat [page1]
        end

        it "returns nil" do
          expect(ui_state.find_tree_node(pages)).to be_nil
        end
      end
    end

    describe "#find_tab" do
      let(:pager) { double("TreePager") }
      let(:tab1) { double("tab1", label: "Tab 1") }
      let(:tab2) { double("tab2", label: "Tab 2") }
      let(:tabs) { [tab1, tab2] }

      context "if the user has still not clicked in any tab" do
        before { MyUIState.create_instance }

        it "returns nil" do
          expect(ui_state.find_tab(tabs)).to be_nil
        end
      end

      context "if the user has switched to a tab in the current tree node" do
        before { ui_state.switch_to_tab(tab2) }

        it "selects the corresponding page" do
          expect(ui_state.find_tab(tabs)).to eq tab2
        end
      end

      context "if the switched to a tab but then moved to a different tree node" do
        let(:another_page) { double("Page", label: "A section") }

        before do
          ui_state.switch_to_tab(tab2)
          ui_state.go_to_tree_node(another_page)
        end

        it "returns nil even if there is another tab with the same label" do
          expect(ui_state.find_tab(tabs)).to be_nil
        end
      end
    end

    describe "#row_id" do
      let(:row_id) { "my-row" }
      context "if the user has still not selected any row" do
        before { MyUIState.create_instance }

        it "returns nil" do
          expect(ui_state.row_id).to be_nil
        end
      end

      context "if the user has selected a row" do
        before { ui_state.select_row(row_id) }

        it "returns the row id" do
          expect(ui_state.row_id).to eq(row_id)
        end
      end

      context "if the user had selected a row but then moved to a different tab" do
        let(:another_tab) { double("Tab", label: "A tab") }

        before do
          ui_state.select_row(row_id)
          ui_state.switch_to_tab(another_tab)
        end

        it "returns nil" do
          expect(ui_state.row_id).to be_nil
        end
      end

      context "if the user had selected a row but then moved to a different tree node" do
        let(:another_page) { double("Page", label: "Somewhere") }

        before do
          ui_state.select_row(row_id)
          ui_state.go_to_tree_node(another_page)
        end

        it "returns nil" do
          expect(ui_state.row_id).to be_nil
        end
      end
    end
  end
end
