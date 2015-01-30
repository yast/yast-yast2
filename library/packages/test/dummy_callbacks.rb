#!/usr/bin/env rspec

require_relative "test_helper"

require "packages/dummy_callbacks"

class FakePkg
  class << self
    def method_missing(met, *args, &block)
      signature = args.first.signature
      if signature.include?("()")
        args_count = 0
      else
        args_count = signature.count(",") + 1
      end

      passed_args = Array.new(args_count, nil)
      args.first.call(*passed_args) # try to call method to avoid syntax errors and typos
    end
  end
end

describe Packages::DummyCallbacks do
  before do
    stub_const("Yast::Pkg", FakePkg)
  end

  it "registers valid methods to Pkg" do
    expect{Packages::DummyCallbacks.register}.to_not raise_error
  end
end

