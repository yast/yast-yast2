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
require "yast"

module Yast
  # Provides assertions for old yast testsuite
  # @deprecated use rspec tests instead
  class AssertClass < Module
    # @param [Object] expected expected value of test
    # @param [Object] actual   actual value of test
    # @param [String] fail_message will be logged if test fails
    # @return whether test succeeds
    def EqualMsg(expected, actual, fail_message)
      expected = deep_copy(expected)
      actual = deep_copy(actual)
      return true if expected == actual

      Builtins.y2error("%1", fail_message)
      false
    end

    # @param [Object] expected expected value of test
    # @param [Object] actual   actual value of test
    # @return whether test succeeds
    def Equal(expected, actual)
      expected = deep_copy(expected)
      actual = deep_copy(actual)
      fail_message = Builtins.sformat(
        "assertion failure, expected '%1', got '%2'",
        expected,
        actual
      )
      EqualMsg(expected, actual, fail_message)
    end

    publish function: :EqualMsg, type: "boolean (any, any, string)"
    publish function: :Equal, type: "boolean (any, any)"
  end

  Assert = AssertClass.new
end
