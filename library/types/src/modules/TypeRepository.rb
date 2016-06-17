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
# File:	modules/TypeRepository.ycp
# Package:	yast2
# Summary:	Type repository for validation of user-defined types
# Authors:	Stanislav Visnovsky <visnov@suse.cz>
# Flags:	Stable
#
# $Id$
require "yast"

module Yast
  class TypeRepositoryClass < Module
    def main
      Yast.import "Address"
      Yast.import "Hostname"
      Yast.import "IP"
      Yast.import "Netmask"
      Yast.import "URL"

      # Map of known types, empty initially
      @types = {}
      TypeRepository()
    end

    # Validate, that the given value is of given type.
    #
    # @param [Object] value	value to be validated
    # @param [String] type type against which to validate
    # @return true, if the value can be considered to be of a given type
    def is_a(value, type)
      value = deep_copy(value)
      validator = Ops.get(@types, type)
      return validator.call(value) if !validator.nil?

      Builtins.y2error("Request to validate unknown type %1", type)
      false
    end

    # Check, if s is a string.
    #
    # @param [Object] s		a value to be validated
    # @return		true if s is string
    def is_string(s)
      s = deep_copy(s)
      Ops.is_string?(s)
    end

    # Constructor, defines the known types.
    def TypeRepository
      @types = {
        "ip"           => fun_ref(IP.method(:Check), "boolean (string)"),
        "ip4"          => fun_ref(IP.method(:Check4), "boolean (string)"),
        "ip6"          => fun_ref(IP.method(:Check6), "boolean (string)"),
        "netmask"      => fun_ref(Netmask.method(:Check), "boolean (string)"),
        "netmask4"     => fun_ref(Netmask.method(:Check4), "boolean (string)"),
        "netmask6"     => fun_ref(Netmask.method(:Check6), "boolean (string)"),
        "host"         => fun_ref(Address.method(:Check), "boolean (string)"),
        "host4"        => fun_ref(Address.method(:Check4), "boolean (string)"),
        "host6"        => fun_ref(Address.method(:Check6), "boolean (string)"),
        "hostname"     => fun_ref(Hostname.method(:Check), "boolean (string)"),
        "fullhostname" => fun_ref(Hostname.method(:CheckFQ), "boolean (string)"),
        "domain"       => fun_ref(
          Hostname.method(:CheckDomain),
          "boolean (string)"
        ),
        "url"          => fun_ref(URL.method(:Check), "boolean (string)"),
        "string"       => fun_ref(method(:is_string), "boolean (any)")
      }

      nil
    end

    # Checks if given argument is empty.
    #
    # For other types than string, list, map returns true when value is nil.
    # For list and map checks if value is nil or doesn't contain any item ( [] resp $[] ).
    # For string checks if value is nil or equal to string without any chars ("").
    def IsEmpty(value)
      value = deep_copy(value)
      return true if value.nil?

      ret = false

      ret = Builtins.isempty(Convert.to_string(value)) if Ops.is_string?(value)

      ret = Builtins.isempty(Convert.to_list(value)) if Ops.is_list?(value)

      ret = Builtins.isempty(Convert.to_map(value)) if Ops.is_map?(value)

      ret = Builtins.size(Convert.to_term(value)) == 0 if Ops.is_term?(value)

      ret
    end

    # ************************ generic validators ******************************

    #  Generic regular expression validator.
    #
    #  @param [String] regex	the regular expression to be matched
    #  @param [String] value	the value to be matched
    #  @return	true if successful
    def regex_validator(regex, value)
      Builtins.regexpmatch(value, regex)
    end

    #  Generic enumerated type validator.
    #
    #  @param [Array] values	a list of possible values
    #  @param [String] value	the value to be matched
    #  @return	true if successful
    def enum_validator(values, value)
      values = deep_copy(values)
      Builtins.contains(values, value)
    end

    publish function: :is_a, type: "boolean (any, string)"
    publish function: :TypeRepository, type: "void ()"
    publish function: :IsEmpty, type: "boolean (any)"
    publish function: :regex_validator, type: "boolean (string, string)"
    publish function: :enum_validator, type: "boolean (list, string)"
  end

  TypeRepository = TypeRepositoryClass.new
  TypeRepository.main
end
