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
# File:	modules/Punycode.ycp
# Package:	Main yast package
# Summary:	DNS Punycode Handling
# Authors:	Lukas Ocilka <lukas.ocilka@suse.cz>
# Tags:	Unstable
#
# $Id$
#
require "yast"

module Yast
  class PunycodeClass < Module
    def main
      textdomain "base"

      @tmp_dir = nil

      # string, matching this regexp, is not cached
      @not_cached_regexp = "^[0123456789.]*$"

      #
      # Encoded string in cache has the same index
      # as its Decoded format in the second list.
      #

      # list of encoded strings to be cached (Punycode or Unicode)
      @cache_encoded = []
      # list of decoded strings to be cached (Unicode or Punycode)
      @cache_decoded = []

      @current_cache_index = 0

      # cached amount of data should be controled
      @current_cache_size = 0
      @maximum_cache_size = 32_768
    end

    # Returns the maximum cache size (sum of already converted
    # strings).
    #
    # @return [Fixnum] maximum_cache_size
    # @see #SetMaximumCacheSize()
    def GetMaximumCacheSize
      @maximum_cache_size
    end

    # Offers to set the maximum cache size (sum of already
    # converted strings).
    #
    # @param [Fixnum] new_max_size
    # @see #GetMaximumCacheSize()
    def SetMaximumCacheSize(new_max_size)
      if !new_max_size.nil?
        @maximum_cache_size = new_max_size
      else
        Builtins.y2error("Cannot set MaximumCacheSize to nil!")
      end

      nil
    end

    # Adds new cache records for encoded and decoded strings.
    #
    # @param [String] decoded
    # @param [String] encoded
    def CreateNewCacheRecord(decoded, encoded)
      # Erroneous cache record
      return if decoded.nil? || encoded.nil?

      # Already cached
      return if Builtins.contains(@cache_decoded, decoded)

      decoded_size = Builtins.size(decoded)
      encoded_size = Builtins.size(encoded)

      # Do not store this record if the cache would exceed maximum
      if Ops.greater_than(
        Ops.add(Ops.add(@current_cache_size, decoded_size), encoded_size),
        @maximum_cache_size
      )
        return
      end

      @current_cache_size = Ops.add(
        Ops.add(@current_cache_size, decoded_size),
        encoded_size
      )
      Ops.set(@cache_decoded, @current_cache_index, decoded)
      Ops.set(@cache_encoded, @current_cache_index, encoded)
      @current_cache_index = Ops.add(@current_cache_index, 1)

      nil
    end

    # Returns string encoded in Punycode if it has been
    # already cached. Returns nil if not found.
    #
    # @param [String] decoded_string (Unicode)
    # @return [String] encoded_string (Punycode)
    def GetEncodedCachedString(decoded_string)
      ret = nil

      # numbers and empty strings are not converted
      if Builtins.regexpmatch(decoded_string, @not_cached_regexp)
        return decoded_string
      end

      counter = -1
      # searching through decoded strings to find the index
      Builtins.foreach(@cache_decoded) do |cached_string|
        counter = Ops.add(counter, 1)
        if cached_string == decoded_string
          # returning encoded representation
          ret = Ops.get(@cache_encoded, counter)
          raise Break
        end
      end

      ret
    end

    # Returns string encoded in Punycode if it has been
    # already cached. Returns nil if not found.
    #
    # @param [String] encoded_string (Punycode)
    # @return [String] decoded_string (Unicode)
    def GetDecodedCachedString(encoded_string)
      ret = nil

      # numbers and empty strings are not converted
      if Builtins.regexpmatch(encoded_string, @not_cached_regexp)
        return encoded_string
      end

      counter = -1
      # searching through encoded strings to find the index
      Builtins.foreach(@cache_encoded) do |cached_string|
        counter = Ops.add(counter, 1)
        if cached_string == encoded_string
          # returning decoded representation
          ret = Ops.get(@cache_decoded, counter)
          raise Break
        end
      end

      ret
    end

    # Returns the current temporary directory.
    # Lazy loading for the initialization is used.
    def GetTmpDirectory
      if @tmp_dir.nil?
        @tmp_dir = Convert.to_string(SCR.Read(path(".target.tmpdir")))
      end

      @tmp_dir
    end

    # Function takes the list of strings and returns them in the converted
    # format. Unicode to Punycode or Punycode to Unicode (param to_punycode).
    # It uses a cache of already-converted strings.
    def ConvertBackAndForth(strings_in, to_punycode)
      strings_in = deep_copy(strings_in)
      # list of returned strings
      strings_out = []

      # Some (or maybe all) strings needn't be cached
      not_cached = []

      # Check the cache for already entered strings
      current_index = -1
      test_cached = Builtins.listmap(strings_in) do |string_in|
        string_out = nil
        # Numbers, IPs and empty strings are not converted
        if Builtins.regexpmatch(string_in, @not_cached_regexp)
          string_out = string_in
        else
          if to_punycode
            string_out = GetEncodedCachedString(string_in)
          else
            string_out = GetDecodedCachedString(string_in)
          end
        end
        if string_out.nil?
          current_index = Ops.add(current_index, 1)
          Ops.set(not_cached, current_index, string_in)
        end
        { string_in => string_out }
      end

      converted_not_cached = []

      # There is something not cached, converting them at once
      if not_cached != []
        tmp_in = Ops.add(GetTmpDirectory(), "/tmp-idnconv-in.ycp")
        tmp_out = Ops.add(GetTmpDirectory(), "/tmp-idnconv-out.ycp")

        SCR.Write(path(".target.ycp"), tmp_in, not_cached)
        convert_command = Builtins.sformat(
          "/usr/bin/idnconv %1 %2 > %3",
          to_punycode ? "" : "-reverse",
          tmp_in,
          tmp_out
        )

        if Convert.to_integer(
          SCR.Execute(path(".target.bash"), convert_command)
        ) != 0
          Builtins.y2error("Conversion failed!")
        else
          converted_not_cached = Convert.convert(
            SCR.Read(path(".target.ycp"), tmp_out),
            from: "any",
            to:   "list <string>"
          )
          # Parsing the YCP file failed
          if converted_not_cached.nil?
            Builtins.y2error(
              "Erroneous YCP file: %1",
              SCR.Read(path(".target.string"), tmp_out)
            )
          end
        end
      end

      # Listing through the given list and adjusting the return list
      current_index = -1
      found_index = -1
      Builtins.foreach(strings_in) do |string_in|
        current_index = Ops.add(current_index, 1)
        # Already cached string
        if !Ops.get(test_cached, string_in).nil?
          Ops.set(
            strings_out,
            current_index,
            Ops.get(test_cached, string_in, "")
          )

          # Recently converted strings
        else
          found_index = Ops.add(found_index, 1)
          Ops.set(
            strings_out,
            current_index,
            Ops.get(converted_not_cached, found_index, "")
          )

          # Adding converted strings to cache
          if to_punycode
            CreateNewCacheRecord(
              string_in,
              Ops.get(converted_not_cached, found_index, "")
            )
          else
            CreateNewCacheRecord(
              Ops.get(converted_not_cached, found_index, ""),
              string_in
            )
          end
        end
      end

      deep_copy(strings_out)
    end

    # Converts list of UTF-8 strings into their Punycode
    # ASCII repserentation.
    #
    # @param [Array<String>] punycode_strings
    # @return [Array<String>] encoded_strings
    def EncodePunycodes(punycode_strings)
      punycode_strings = deep_copy(punycode_strings)
      ConvertBackAndForth(punycode_strings, true)
    end

    # Converts list of Punycode strings into their UTF-8
    # representation.
    #
    # @param [Array<String>] punycode_strings
    # @return [Array<String>] decoded_strings
    def DecodePunycodes(punycode_strings)
      punycode_strings = deep_copy(punycode_strings)
      ConvertBackAndForth(punycode_strings, false)
    end

    # Encodes the domain name (relative or FQDN) to the Punycode.
    #
    # @param string decoded domain_name
    # @return [String] encoded domain_name
    #
    # @example
    #	EncodeDomainName("žížala.jůlinka.go.home")
    #		-> "xn--ala-qma83eb.xn--jlinka-3mb.go.home"
    def EncodeDomainName(decoded_domain_name)
      Builtins.mergestring(
        EncodePunycodes(Builtins.splitstring(decoded_domain_name, ".")),
        "."
      )
    end

    # Decodes the domain name (relative or FQDN) from the Punycode.
    #
    # @param [String] encoded_domain_name
    # @return [String] decoded domain_name
    #
    # @example
    #	DecodeDomainName("xn--ala-qma83eb.xn--jlinka-3mb.go.home")
    #		-> "žížala.jůlinka.go.home"
    def DecodeDomainName(encoded_domain_name)
      Builtins.mergestring(
        DecodePunycodes(Builtins.splitstring(encoded_domain_name, ".")),
        "."
      )
    end

    # Decodes the list of domain names to their Unicode representation.
    # This function is similar to DecodePunycodes but it works with every
    # string as a domain name (that means every domain name is parsed
    # by dots and separately evaluated).
    #
    # @param [Array<String>] encoded_domain_names
    # @return [Array<String>] decoded_domain_names
    #
    # @example
    # 	DocodeDomainNames(["mx1.example.org", "xp3.example.org.", "xn--ala-qma83eb.org.example."])
    #		-> ["mx1.example.org", "xp3.example.org.", "žížala.org.example."]
    def DocodeDomainNames(encoded_domain_names)
      encoded_domain_names = deep_copy(encoded_domain_names)
      decoded_domain_names = []
      strings_to_decode = []

      # $[0 : [0, 2], 1 : [3, 5]]
      backward_map_of_conversion = {}

      current_domain_index = -1
      current_domain_item = 0

      # parsing all domain names one by one
      Builtins.foreach(encoded_domain_names) do |one_domain_name|
        current_domain_index = Ops.add(current_domain_index, 1)
        start = current_domain_item
        # parsing the domain name by dots
        Builtins.foreach(Builtins.splitstring(one_domain_name, ".")) do |domain_item|
          Ops.set(strings_to_decode, current_domain_item, domain_item)
          current_domain_item = Ops.add(current_domain_item, 1)
        end
        # creating backward index
        Ops.set(
          backward_map_of_conversion,
          current_domain_index,
          [start, Ops.subtract(current_domain_item, 1)]
        )
      end

      # Transformating strings to the decoded format
      strings_to_decode = DecodePunycodes(strings_to_decode)

      current_domain_index = -1
      Builtins.foreach(encoded_domain_names) do |one_encoded|
        current_domain_index = Ops.add(current_domain_index, 1)
        # Where the current string starts and ends
        current = Ops.get(backward_map_of_conversion, [current_domain_index, 0])
        end_ = Ops.get(backward_map_of_conversion, [current_domain_index, 1])
        # error?
        if current.nil? || end_.nil?
          Builtins.y2error(
            "Cannot find start/end for %1 in %2",
            one_encoded,
            Ops.get(backward_map_of_conversion, current_domain_index)
          )
          Ops.set(decoded_domain_names, current_domain_index, one_encoded)
        else
          # create a list of items of the current domain (translated)
          decoded_domain = []
          while Ops.less_or_equal(current, end_)
            decoded_domain = Builtins.add(
              decoded_domain,
              Ops.get(strings_to_decode, current, "")
            )
            current = Ops.add(current, 1)
          end
          # create a domain name from these strings
          Ops.set(
            decoded_domain_names,
            current_domain_index,
            Builtins.mergestring(decoded_domain, ".")
          )
        end
      end

      deep_copy(decoded_domain_names)
    end

    publish function: :GetMaximumCacheSize, type: "integer ()"
    publish function: :SetMaximumCacheSize, type: "void (integer)"
    publish function: :EncodePunycodes, type: "list <string> (list <string>)"
    publish function: :DecodePunycodes, type: "list <string> (list <string>)"
    publish function: :EncodeDomainName, type: "string (string)"
    publish function: :DecodeDomainName, type: "string (string)"
    publish function: :DocodeDomainNames, type: "list <string> (list <string>)"
  end

  Punycode = PunycodeClass.new
  Punycode.main
end
