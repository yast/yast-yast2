# typed: false
# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2002 - 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# ***************************************************************************
# File:	modules/GetInstArgs.rb
# Package:	yast2
# Summary:	Get client arguments
# Authors:	Anas Nashif <nashif@suse.de>
#
require "yast"

module Yast
  class GetInstArgsClass < Module
    def main
      @args = {}
    end

    def Init
      # Check arguments
      @args = {}
      i = 0
      # assign to args first available map
      # (in proposals, first argument is string - bnc#475169)
      while Ops.less_than(i, Builtins.size(WFM.Args))
        if Ops.is_map?(WFM.Args(i))
          @args = Convert.to_map(WFM.Args(i))
          break
        end
        i = Ops.add(i, 1)
      end
      Builtins.y2milestone("args=%1", @args)

      nil
    end

    # Should be the [Next] button enabled?
    #
    # @return [Boolean] whether enabled or not
    def enable_next
      Init()
      Ops.get_boolean(@args, "enable_next", false)
    end

    # Should be the [Back] button enabled?
    #
    # @return [Boolean] whether enabled or not
    def enable_back
      Init()
      Ops.get_boolean(@args, "enable_back", false)
    end

    # Are we going back from the previous dialog?
    #
    # @return [Boolean] whether going_back or not
    def going_back
      Init()
      Ops.get_boolean(@args, "going_back", false)
    end

    # Returns name of the proposal
    #
    # @return [String] proposal name
    #
    # @example
    #	GetInstArgs::proposal() -> "initial"
    #	GetInstArgs::proposal() -> "network"
    #	GetInstArgs::proposal() -> "hardware"
    def proposal
      Init()
      Ops.get_string(@args, "proposal", "")
    end

    # Returns map of client parameters
    #
    # @return [Hash] of parameters
    #
    # @example
    #	GetInstArgs::argmap() -> $[
    #		"enable_back" : true,
    #		"enable_next" : true,
    #		"going_back"  : true,
    #		"anything"    : "yes, of course",
    #	]
    def argmap
      Init()
      deep_copy(@args)
    end

    # Returns map of client parameters only with keys:
    # "enable_back", "enable_next", and "proposal"
    #
    # @return [Hash] of parameters
    #
    # @example
    #	GetInstArgs::ButtonsProposal() -> $[
    #		"enable_back" : true,
    #		"enable_next" : true,
    #		"proposal"  : "initial"
    #	]
    def ButtonsProposal(back, next_, proposal_name)
      {
        "enable_back" => back,
        "enable_next" => next_,
        "proposal"    => proposal_name
      }
    end

    # Returns map of client parameters only with keys:
    # "enable_back" and "enable_next"
    #
    # @return [Hash] of parameters
    #
    # @example
    #	GetInstArgs::Buttons() -> $[
    #		"enable_back" : false,
    #		"enable_next" : true
    #	]
    def Buttons(back, next_)
      {
        "enable_back" => back,
        "enable_next" => next_
      }
    end

    publish function: :enable_next, type: "boolean ()"
    publish function: :enable_back, type: "boolean ()"
    publish function: :going_back, type: "boolean ()"
    publish function: :proposal, type: "string ()"
    publish function: :argmap, type: "map ()"
    publish function: :ButtonsProposal, type: "map (boolean, boolean, string)"
    publish function: :Buttons, type: "map (boolean, boolean)"
  end

  GetInstArgs = GetInstArgsClass.new
  GetInstArgs.main
end
