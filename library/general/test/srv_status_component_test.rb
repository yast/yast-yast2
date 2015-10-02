#! /usr/bin/env rspec

require_relative "test_helper"
require "ui/srv_status_component"

# Some helpers to test the UI

def matches_id_and_text?(widget, id, text)
  return false unless widget.is_a?(Yast::Term)
  return false unless widget.params
  return false unless widget.params.any? do |p|
    p.is_a?(Yast::Term) && p.value == :id && p.params.first =~ id
  end
  return widget.params.any? {|p| p.is_a?(::String) && p =~ text }
end

def widget_by_id_and_text(widgets, id, text)
  widgets.nested_find do |t|
    matches_id_and_text?(t, /#{id}/, /#{Yast::_(text)}/)
  end
end

def options_for(term)
  opt = term.params.find do |p|
    p.is_a?(Yast::Term) && p.value == :opt
  end
  opt.params
end

def id_for(term)
  id = term.params.find do |p|
    p.is_a?(Yast::Term) && p.value == :id
  end
  id.params.first
end

# Class using SrvStatusComponent
class DummyDialog
  include Yast::UIShortcuts

  attr_reader :enabled1, :enabled2, :srv1_component, :srv2_component

  def initialize
    @srv1_component = ::UI::SrvStatusComponent.new(
      "service1",
      enabled_callback: ->(e) { @enabled1 = e }
    )
    @srv2_component = ::UI::SrvStatusComponent.new("service2")
    @enabled1 = @srv1_component.enabled?
    @enabled2 = @srv2_component.enabled?
  end

  def handle_input(input)
    @srv1_component.handle_input(input)
    @srv2_component.handle_input(input)
  end

  def content
    VBox(
      Heading("Dummy dialog"),
      @srv1_component.widget,
      @srv2_component.widget,
      PushButton(Id(:ok), "Ok")
    )
  end
end

module Yast
  extend Yast::I18n
  Yast::textdomain "base"

  import "Service"
  import "UI"

  describe ::UI::SrvStatusComponent do
    before do
      allow(Yast::Service).to receive(:enabled?).with("service1").and_return true
      allow(Yast::Service).to receive(:enabled?).with("service2").and_return false
      allow(Yast::Service).to receive(:active?).with("service1").and_return true
      allow(Yast::Service).to receive(:active?).with("service2").and_return false
    end

    let(:dialog) { DummyDialog.new }
    let(:widgets) { dialog.content }
    let(:stop_service1) { widget_by_id_and_text(widgets, "service1", "Stop now") }
    let(:start_service2) { widget_by_id_and_text(widgets, "service2", "Start now") }
    let(:reload_service1) { widget_by_id_and_text(widgets, "service1", "Reload After Saving Settings") }
    let(:reload_service2) { widget_by_id_and_text(widgets, "service2", "Reload After Saving Settings") }
    let(:enabled_service1) { widget_by_id_and_text(widgets, "service1", "Start During System Boot") }
    let(:enabled_service2) { widget_by_id_and_text(widgets, "service2", "Start During System Boot") }

    describe "#initialize" do
      it "reads the initial enabled state from the system" do
        expect(dialog.enabled1).to eq true
        expect(dialog.enabled2).to eq false
      end
    end

    describe "#widget" do
      it "includes all the UI elements" do
        expect(stop_service1).not_to be_nil
        expect(start_service2).not_to be_nil
        expect(reload_service1).not_to be_nil
        expect(reload_service2).not_to be_nil
        expect(enabled_service1).not_to be_nil
        expect(enabled_service2).not_to be_nil
      end

      it "disables and unchecks the reload button for stopped services" do
        expect(options_for(reload_service2).any? {|p| p == :disabled })
        expect(reload_service2.params.last).to eq false
      end

      it "enables the reload button for stopped services" do
        expect(options_for(reload_service1).none? {|p| p == :disabled })
      end
    end

    describe "#handle_input" do
      it "stops the service on user request" do
        expect(Yast::Service).to receive(:Stop).with("service1")
        dialog.handle_input(id_for(stop_service1))
      end

      it "starts the service on user request" do
        expect(Yast::Service).to receive(:Start).with("service2")
        dialog.handle_input(id_for(start_service2))
      end

      it "triggers 'enabled_callback' if available" do
        allow(Yast::UI).to receive(:QueryWidget).and_return "new_value"
        dialog.handle_input(id_for(enabled_service1))

        expect(dialog.enabled1).to eq "new_value"
      end

      it "changes the result of #enabled? on user request" do
        expect(dialog.srv1_component.enabled?).to eq true

        allow(Yast::UI).to receive(:QueryWidget).and_return false
        dialog.handle_input(id_for(enabled_service1))

        expect(dialog.srv1_component.enabled?).to eq false
      end
    end
  end
end
