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
# File:  modules/Integer.ycp
# Package:  yast2
# Summary:  Integer routines
# Authors:  Arvin Schnell <aschnell@suse.de>
#
# $Id: Integer.ycp 45945 2008-04-01 19:41:01Z aschnell $
require "yast"

module Yast
  class IntegerClass < Module
    def main
      textdomain "base"
    end

    # Generate a list<integer> with the integers from 0 to stop - 1.
    def Range(stop)
      ret = []
      i = 0
      while Ops.less_than(i, stop)
        ret = Builtins.add(ret, i)
        i = Ops.add(i, 1)
      end
      deep_copy(ret)
    end

    # Generate a list<integer> with the integers from start to stop - 1.
    def RangeFrom(start, stop)
      ret = []
      i = start
      while Ops.less_than(i, stop)
        ret = Builtins.add(ret, i)
        i = Ops.add(i, 1)
      end
      deep_copy(ret)
    end

    # Checks whether i is a power of two. That is 1, 2, 4, 8, ... .
    def IsPowerOfTwo(input)
      Ops.greater_than(input, 0) && Ops.bitwise_and(input, Ops.subtract(input, 1)) == 0
    end

    # Calculates the sum of values.
    def Sum(values)
      return nil unless values

      values.reduce(0, :+)
    end

    # Returns the smallest integer in values.
    #
    # Behaviour is undefined for empty values.
    def Min(values)
      return nil unless values

      values.min
    end

    # Returns the highest integer in values.
    #
    # Behaviour is undefined for empty values.
    def Max(values)
      return nil unless values

      values.max
    end

    # Clamps the integer i.
    def Clamp(number, min, max)
      return min if Ops.less_than(number, min)
      return max if Ops.greater_than(number, max)

      number
    end

    publish function: :Range, type: "list <integer> (integer)"
    publish function: :RangeFrom, type: "list <integer> (integer, integer)"
    publish function: :IsPowerOfTwo, type: "boolean (integer)"
    publish function: :Sum, type: "integer (list <integer>)"
    publish function: :Min, type: "integer (list <integer>)"
    publish function: :Max, type: "integer (list <integer>)"
    publish function: :Clamp, type: "integer (integer, integer, integer)"
  end

  Integer = IntegerClass.new
  Integer.main
end
