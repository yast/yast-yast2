#! /usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

module Yast
  import 'Hooks'

  # test hook files are located in test/hooks directory

  describe Hooks do
    before do
      Hooks.all.clear
      Hooks.search_path.set File.join(__dir__, 'hooks')
    end

    it "executes single hook specified by a name" do
      Hooks.run :before_hook
      expect(Hooks.find(:before_hook)).not_to be_nil
      expect(Hooks.last.files.size).to eq(2)
    end

    it "allows to retrieve information about hooks" do
      expect(Hooks.exists?(:before_hook)).to eq(false)
      expect(Hooks.find(:before_hook)).to eq(nil)
      expect(Hooks.all).to be_empty

      Hooks.run :before_hook
      expect(Hooks.exists?(:before_hook)).to eq(true)
      expect(Hooks.find(:before_hook)).not_to eq(nil)
      expect(Hooks.all).not_to be_empty
      expect(Hooks.all.size).to eq(1)
      expect(Hooks.find(:before_hook).failed?).to eq(true)
      expect(Hooks.find(:before_hook).succeeded?).to eq(false)
    end

    it "tracks the results of the run hook files" do
      Hooks.run :before_hook
      expect(Hooks.last.results.size).to eq(2)
      failed_hook_file = Hooks.find(:before_hook).results.first
      expect(failed_hook_file.exit).not_to eq(0)
      expect(failed_hook_file.stderr).to match(/failure/)

      succeeded_hook_file = Hooks.find(:before_hook).results.last
      expect(succeeded_hook_file.exit).to eq(0)
      expect(succeeded_hook_file.stdout).to match(/success/)
    end
  end
end
