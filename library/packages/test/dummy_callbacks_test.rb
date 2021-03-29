#!/usr/bin/env rspec
# typed: false

require_relative "test_helper"

require "packages/dummy_callbacks"

class FakePkg
  class << self
    def method_missing(_met, *args, &_block) # rubocop:disable Style/MethodMissingSuper
      signature = args.first.signature
      args_count = signature.include?("()") ? 0 : (signature.count(",") + 1)

      passed_args = Array.new(args_count, nil)
      args.first.call(*passed_args) # try to call method to avoid syntax errors and typos
    end

    def respond_to_missing?(_name, _include_private)
      true
    end
  end
end

describe Packages::DummyCallbacks do
  before do
    stub_const("Yast::Pkg", FakePkg)
  end

  it "registers valid methods to Pkg" do
    expect { Packages::DummyCallbacks.register }.to_not raise_error
  end
end
