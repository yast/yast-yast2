#! /usr/bin/env rspec

require_relative "test_helper"

require "ui/widgets"

describe ::UI::Widgets::KeyboardLayoutTest do
  it "has label" do
    expect(subject.label).to be_a(::String)
  end
end
