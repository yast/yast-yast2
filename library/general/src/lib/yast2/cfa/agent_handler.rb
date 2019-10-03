# Copyright (c) [2019] SUSE LLC
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

require "yast"
require "yaml"

module Yast2
  module CFA
    # This class reads/writes information through YaST2 agents
    #
    # It offers a File-like API (#read and #write methods) in order to read
    # and write information using YaST2 agents.
    #
    # == Why?
    #
    # Usually, YaST2 agents contain the filename hardcoded in their definition (.scr files).
    # So it is not possible to select a different file to read information from (like +/etc/modprobe.conf+,
    # +/etc/modprobe.d/50-yast.conf+).
    #
    # Through this class, you can define the path on the fly. Agents are registered/unregistered as needed
    # (FIXME: try to find out the performance penalty).
    #
    # @example Get +/etc/nsswitch.conf+ information from different sources.
    #   handler = CFA::Yast::AgentHandler.new(
    #     :ag_ini,
    #     :IniAgent,
    #     "options"  =>  ["ignore_case", "global_values", "flat"],
    #     "comments" => ["^#.*", "^[ \t]*$"],
    #     "params"   => [
    #       "match" => [ "^[ \t]*([a-zA-Z0-9_]+)[ \t]*:[ \t]*(.*[^ \t]|)[ \t]*$", "%s:\t%s" ]
    #     ]
    #   )
    #   handler.read("/etc/nsswitch.conf") #=> <Hash::...>
    #   handler.read("/etc/nsswitch.d/50-yast.conf") #=> <Hash::...>
    #
    # == TODO
    #
    # This is just a PoC but, there are somethings that we might need to address:
    #
    # * Read and writer are returning/expecting hashes. To mimic File behaviour, they should return
    #   a string which should be parsed by a CFA Parse. I am not sure whether it worths the
    #   conversion at all.
    # * The CFA parser class is missing.
    class AgentHandler
      # Constructor
      #
      # @param agent   [Symbol] Agent name (e.g., :ag_ini)
      # @param source  [Symbol] Agent source (e.g., :SysConfigFile, :IniFile, etc.)
      # @param options [Hash<String,Array>] Agent options
      def initialize(agent, source, options = {})
        @agent = agent
        @source = source
        @options = options
      end

      # Reads the content from the agent
      #
      # @param [String] Filename
      # @return [String] FIXME: string representation
      def read(filename)
        with_registered_agent(filename) do |scr_path|
          keys = ::Yast::SCR.Dir(scr_path)
          keys.each_with_object({}) do |key, all|
            all[key] = ::Yast::SCR.Read("#{scr_path}.#{key}")
          end
        end
      end

      # Writes the content through the agent
      #
      # @param [String] filename
      # @param [String] FIXME: file content
      def write(filename, data)
        with_registered_agent(filename) do |scr_path|
          data.each do |key, value|
            byebug if key == "KBD_DELAY"
            ::Yast::SCR.Write("#{scr_path}.#{key}", value)
          end
        end
      end

    private

      # Registers the agent and runs the given block of code
      #
      # The block receives the agent's path
      #
      # @param filename [String] File name to register the agent for
      # @param block    [Proc]   Block to run
      # @return [Object] Value returned by the block
      def with_registered_agent(filename, &block)
        scr_path = ::Yast::Path.new(".#{File.basename(filename)}")
        ::Yast::SCR.RegisterAgent(scr_path, agent_term(filename)) || raise("Cannot register agent #{scr_path}")
        block.call(scr_path)
      ensure
        ::Yast::SCR.UnregisterAgent(scr_path)
      end

      # Returns the term to define the agent
      #
      # @return [Yast::Term]
      def agent_term(filename)
        args = [@source, filename]
        args << @options unless @options.empty?
        ::Yast.term(
          @agent,
          ::Yast.term(*args)
        )
      end
    end
  end
end
