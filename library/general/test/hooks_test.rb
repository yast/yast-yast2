#! /usr/bin/env rspec
# typed: false

require_relative "test_helper"

module Yast
  import "Hooks"

  # test hook files are located in test/hooks directory

  TEST_HOOK_SEARCH_PATH = File.join(__dir__, "hooks")

  describe Hooks do
    before do
      Hooks.send(:hooks).clear
      Hooks.search_path.set(TEST_HOOK_SEARCH_PATH)
    end

    it "executes single hook specified by a name" do
      hook = Hooks.run "before_hook"
      expect(hook).not_to be_nil
      expect(Hooks.last).not_to be_nil
      expect(Hooks.last).to equal(hook)
      expect(Hooks.find("before_hook")).not_to be_nil
      expect(Hooks.last.files.size).to eq(2)
      expect(hook.search_path.to_s).to eq(TEST_HOOK_SEARCH_PATH)
      expect(hook.search_path.reset).not_to eq(TEST_HOOK_SEARCH_PATH)
    end

    it "executes the same hook if running multiple times" do
      hook_first  = Hooks.run "test_hook"
      hook_second = Hooks.run "test_hook"
      expect(hook_second).to be(hook_first)
    end

    it "allows to retrieve information about hooks" do
      expect(Hooks.exists?("before_hook")).to eq(false)
      expect(Hooks.find("before_hook")).to eq(nil)
      expect(Hooks.all).to be_empty

      hook = Hooks.run "before_hook"
      expect(hook).not_to be_nil
      expect(hook.failed?).to eq(true)
      expect(hook.succeeded?).to eq(false)
      expect(hook.files).not_to be_empty
      expect(hook.files.map(&:content)).not_to be_empty
      expect(Hooks.exists?("before_hook")).to eq(true)
      expect(Hooks.find("before_hook")).not_to eq(nil)
      expect(Hooks.all).not_to be_empty
      expect(Hooks.all.size).to eq(1)
      expect(Hooks.find("before_hook").failed?).to eq(true)
      expect(Hooks.find("before_hook").succeeded?).to eq(false)
    end

    it "tracks the results of the run hook files" do
      Hooks.run "before_hook"
      expect(Hooks.last.results.size).to eq(2)
      failed_hook_file = Hooks.find("before_hook").files.first
      expect(failed_hook_file.result.exit).not_to eq(0)
      expect(failed_hook_file.result.stderr).to match(/failure/)
      expect(failed_hook_file.output).to match(/failure/)

      succeeded_hook_file = Hooks.find("before_hook").files.last
      expect(succeeded_hook_file.result.exit).to eq(0)
      expect(succeeded_hook_file.result.stdout).to match(/success/)
      expect(succeeded_hook_file.output).to match(/success/)
    end

    it "raises exception if the search path for hooks does not exist" do
      Hooks.search_path.set "no/way/this/path/exists"
      expect { Hooks.run("fail_hard")    }.to raise_error
      expect { Hooks.search_path.verify! }.to raise_error
    end
  end
end
