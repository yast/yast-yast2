#! /usr/bin/env rspec

require_relative "test_helper"
require "ui/service_status"

# Some helpers to test the UI

def matches_id_and_text?(widget, id, text)
  return false unless widget.is_a?(Yast::Term)
  return false unless widget.params
  return false unless widget.params.any? do |p|
    p.is_a?(Yast::Term) && p.value == :id && p.params.first =~ id
  end
  widget.params.any? { |p| p.is_a?(::String) && p =~ text }
end

def widget_by_id_and_text(widgets, id, text)
  widgets.nested_find do |t|
    matches_id_and_text?(t, /#{id}/, /#{Yast._(text)}/)
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

class DummyService
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def enabled?
    @name == "active"
  end

  def running?
    @name == "active"
  end

  def start; end
  def stop; end
end

# Class using ServiceStatus
class DummyDialog
  include Yast::UIShortcuts

  attr_reader :enabled1, :enabled2, :srv1_component, :srv2_component

  def initialize(service1, service2)
    @srv1_component = ::UI::ServiceStatus.new(service1)
    @srv2_component = ::UI::ServiceStatus.new(service2)
    @enabled1 = @srv1_component.enabled?
    @enabled2 = @srv2_component.enabled?
  end

  def handle_input(input)
    if @srv1_component.handle_input(input) == :enabled_changed
      @enabled1 = @srv1_component.enabled?
    end
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
  Yast.textdomain "base"

  import "UI"

  describe ::UI::ServiceStatus do
    let(:active) { DummyService.new("active") }
    let(:inactive) { DummyService.new("inactive") }

    let(:dialog) { DummyDialog.new(active, inactive) }
    let(:widgets) { dialog.content }
    let(:stop_active) { widget_by_id_and_text(widgets, "active", "Stop now") }
    let(:start_inactive) { widget_by_id_and_text(widgets, "inactive", "Start now") }
    let(:reload_active) { widget_by_id_and_text(widgets, "active", "Reload After Saving Settings") }
    let(:reload_inactive) { widget_by_id_and_text(widgets, "inactive", "Reload After Saving Settings") }
    let(:enabled_active) { widget_by_id_and_text(widgets, "active", "Start During System Boot") }
    let(:enabled_inactive) { widget_by_id_and_text(widgets, "inactive", "Start During System Boot") }

    describe "#initialize" do
      it "reads the initial enabled state from the system" do
        expect(dialog.enabled1).to eq true
        expect(dialog.enabled2).to eq false
      end
    end

    describe "#widget" do
      it "includes all the UI elements" do
        expect(stop_active).not_to be_nil
        expect(start_inactive).not_to be_nil
        expect(reload_active).not_to be_nil
        expect(reload_inactive).not_to be_nil
        expect(enabled_active).not_to be_nil
        expect(enabled_inactive).not_to be_nil
      end

      it "disables and unchecks the reload button for stopped services" do
        expect(options_for(reload_inactive).any? { |p| p == :disabled })
        expect(reload_inactive.params.last).to eq false
      end

      it "enables the reload button for stopped services" do
        expect(options_for(reload_active).none? { |p| p == :disabled })
      end
    end

    describe "#handle_input" do
      it "stops the service on user request" do
        expect(active).to receive(:stop)
        dialog.handle_input(id_for(stop_active))
      end

      it "starts the service on user request" do
        expect(inactive).to receive(:start)
        dialog.handle_input(id_for(start_inactive))
      end

      it "triggers 'enabled_callback' if available" do
        allow(Yast::UI).to receive(:QueryWidget).and_return "new_value"
        dialog.handle_input(id_for(enabled_active))

        expect(dialog.enabled1).to eq "new_value"
      end

      it "changes the result of #enabled? on user request" do
        expect(dialog.srv1_component.enabled?).to eq true

        allow(Yast::UI).to receive(:QueryWidget).and_return false
        dialog.handle_input(id_for(enabled_active))

        expect(dialog.srv1_component.enabled?).to eq false
      end
    end
  end
end
