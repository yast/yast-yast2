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

require_relative "test_helper"

require "cwm/rspec"
require "cwm/multi_status_selector"

class DummyMultiStatusSelector < CWM::MultiStatusSelector
  def initialize(items)
    @items = items.map { |i| DummyItem.new(i[:id], i[:status], i[:enabled]) }
  end

  attr_reader :items

  class DummyItem < Item
    def initialize(id, status, enabled)
      @id = "dummy-item-#{id}"
      @label = "Label for #{@id}"
      @status = status
      @enabled = enabled
    end

    attr_reader :id, :label, :status

    def enabled?
      @enabled
    end
  end
end

class DummyItem < CWM::MultiStatusSelector::Item
  def initialize(id, status, enabled)
    @id = "dummy-item-#{id}"
    @label = "Label for #{@id}"
    @status = status
    @enabled = enabled
  end

  attr_reader :id, :label, :status
end

describe CWM::MultiStatusSelector do
  subject { DummyMultiStatusSelector.new(items) }

  let(:first_item) { { id: 1, status: :selected, enabled: false } }
  let(:second_item) { { id: 2, status: :unselected, enabled: true } }
  let(:items) { [first_item, second_item] }

  include_examples "CWM::CustomWidget"

  describe "#init" do
    it "renders all items" do
      expect(subject.items).to all(receive(:to_richtext))

      subject.init
    end
  end

  describe "#handle" do
    let(:item) { subject.items.first }
    let(:event) { { "ID" => event_id } }

    context "when handling an event triggered by the check box label" do
      let(:event_id) { "#{item.id}#checkbox#label" }

      it "executes the label event handler" do
        expect(subject).to receive(:label_event_handler).with(item)

        subject.handle(event)
      end

      it "does not execute the input event handler" do
        expect(subject).to_not receive(:input_event_handler)

        subject.handle(event)
      end
    end

    context "when handling an event triggered by the check box input" do
      let(:event_id) { "#{item.id}#checkbox#input" }

      it "executes the input event handler" do
        expect(subject).to receive(:input_event_handler).with(item)

        subject.handle(event)
      end

      it "does not execute the label event handler" do
        expect(subject).to_not receive(:label_event_handler)

        subject.handle(event)
      end
    end

    context "when handling an event not triggered by the item" do
      let(:event) { { "ID" => :whatever } }

      it "does not execute the input event handler" do
        expect(subject).to_not receive(:input_event_handler)

        subject.handle(event)
      end

      it "does not execute the label event handler" do
        expect(subject).to_not receive(:label_event_handler)

        subject.handle(event)
      end
    end
  end
end

describe CWM::MultiStatusSelector::Item do
  subject { DummyMultiStatusSelector::DummyItem.new(id, status, enabled) }

  let(:id) { 99 }
  let(:status) { nil }
  let(:enabled) { true }

  let(:link_id) { "#{subject.id}#{described_class.event_id}" }
  let(:regexp_input_link) { /<a href="#{link_id}.*img.*<\/a>/ }
  let(:regexp_label_link) { /<a href="#{link_id}.*>#{subject.label}<\/a>/ }

  describe "#toggle" do
    context "when item is selected" do
      let(:status) { :selected }

      it "changes to unselected" do
        expect(subject.status).to eq(:selected)

        subject.toggle

        expect(subject.status).to eq(:unselected)
      end
    end

    context "when item is not selected" do
      let(:status) { :unselected }

      it "changes to selected" do
        expect(subject.status).to eq(:unselected)

        subject.toggle

        expect(subject.status).to eq(:selected)
      end
    end

    context "when item is auto selected" do
      let(:status) { :auto_selected }

      it "changes to selected" do
        expect(subject.status).to eq(:auto_selected)

        subject.toggle

        expect(subject.status).to eq(:selected)
      end
    end

    context "when item has an unknown" do
      it "changes to selected" do
        expect(subject.status).to eq(nil)

        subject.toggle

        expect(subject.status).to eq(:selected)
      end
    end
  end

  describe "#enabled?" do
    context "when enabled" do
      let(:enabled) { true }

      it "returns true" do
        expect(subject.enabled?).to eq(true)
      end
    end

    context "when not enabled" do
      let(:enabled) { false }

      it "returns false" do
        expect(subject.enabled?).to eq(false)
      end
    end
  end

  describe "#selected?" do
    context "when selected" do
      let(:status) { :selected }

      it "returns true" do
        expect(subject.selected?).to eq(true)
      end
    end

    context "when not selected" do
      let(:status) { :whatever }

      it "returns false" do
        expect(subject.selected?).to eq(false)
      end
    end
  end

  describe "#select!" do
    it "sets item as selected" do
      subject.select!

      expect(subject.status).to eq(:selected)
    end
  end

  describe "#unselected?" do
    context "when not selected" do
      let(:status) { :whatever }

      it "returns true" do
        expect(subject.unselected?).to eq(true)
      end
    end

    context "when selected" do
      let(:status) { :selected }

      it "returns false" do
        expect(subject.unselected?).to eq(false)
      end
    end

    context "when auto selected" do
      let(:status) { :auto_selected }

      it "returns false" do
        expect(subject.unselected?).to eq(false)
      end
    end
  end

  describe "#unselect!" do
    it "sets item as unselected" do
      subject.unselect!

      expect(subject.status).to eq(:unselected)
    end
  end

  describe "#auto_selected?" do
    context "when auto selected" do
      let(:status) { :auto_selected }

      it "returns true" do
        expect(subject.auto_selected?).to eq(true)
      end
    end

    context "when not auto selected" do
      let(:status) { :selected }

      it "returns false" do
        expect(subject.auto_selected?).to eq(false)
      end
    end
  end

  describe "#auto_select!" do
    it "sets item as auto selected" do
      subject.auto_select!

      expect(subject.status).to eq(:auto_selected)
    end
  end

  describe "#to_richtext" do
    it "returns a string" do
      expect(subject.to_richtext).to be_a(String)
    end

    context "when the item is enabled" do
      it "includes a link for the input" do
        expect(subject.to_richtext).to match(regexp_input_link)
      end

      it "includes a link for the label" do
        expect(subject.to_richtext).to match(regexp_label_link)
      end
    end

    context "when the item is not enabled" do
      let(:enabled) { false }

      it "uses a grey color" do
        expect(subject.to_richtext).to match(/.*color: grey.*/)
      end

      it "includes the item label" do
        expect(subject.to_richtext).to include(subject.label)
      end

      it "does not include a link for the input" do
        expect(subject.to_richtext).to_not match(regexp_input_link)
      end

      it "does not include a link for the label" do
        expect(subject.to_richtext).to_not match(regexp_label_link)
      end
    end

    context "when running in text mode" do
      before { allow(Yast::UI).to receive(:TextMode).and_return(true) }

      context "and the item is selected" do
        let(:status) { :selected }

        it "displays `[x]` as icon" do
          expect(subject.to_richtext).to include("[x]")
        end
      end

      context "and the item is auto selected" do
        let(:status) { :auto_selected }

        it "displays `[a]` as icon" do
          expect(subject.to_richtext).to include("[a]")
        end
      end

      context "and the item is not selected" do
        let(:status) { :unselected }

        it "displays `[ ]` as icon" do
          expect(subject.to_richtext).to include("[ ]")
        end
      end

      context "and the item has an unknown status" do
        let(:status) { :unknown }

        it "displays `[ ]` as icon" do
          expect(subject.to_richtext).to include("[ ]")
        end
      end
    end

    context "when NOT running in text mode" do
      before { allow(Yast::UI).to receive(:TextMode).and_return(false) }

      context "and the item is selected" do
        let(:status) { :selected }

        it "displays the selected icon" do
          expect(subject.to_richtext).to include("checkbox-on.svg")
        end
      end

      context "and the item is auto selected" do
        let(:status) { :auto_selected }

        it "displays the auto-selected icon" do
          expect(subject.to_richtext).to include("auto-selected.svg")
        end
      end

      context "and the item is not selected" do
        let(:status) { :unselected }

        it "displays the unselected icon" do
          expect(subject.to_richtext).to include("checkbox-off.svg")
        end
      end

      context "and the item has an unknown status" do
        let(:status) { :unknown }

        it "displays the unselected icon" do
          expect(subject.to_richtext).to include("checkbox-off.svg")
        end
      end
    end
  end
end
