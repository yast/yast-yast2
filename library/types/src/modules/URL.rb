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
# File:	modules/URL.ycp
# Package:	yast2
# Summary:	Manipulate and Parse URLs
# Authors:	Michal Svec <msvec@suse.cz>
#		Anas Nashif <nashif@suse.cz>
# Flags:	Stable
#
# $Id$
require "yast"
require 'uri'

module URI
  class SMB < Generic
    def domain
      self.query[/workgroup=(.*)/,1]
    end
  end
  @@schemes['SMB'] = SMB
  @@schemes['SAMBA'] = SMB
end

module Yast
  class URLClass < Module
    include Yast::Logger

    def main
      textdomain "base"

      Yast.import "Hostname"
      Yast.import "String"
      Yast.import "IP"
      Yast.import "URLRecode"

      # TODO:
      # - read URI(3)
      # - esp. compare the regex mentioned in the URI(3) with ours:
      #   my($scheme, $authority, $path, $query, $fragment) =
      #   $uri =~ m|^(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|;

      # Valid characters in URL
      #
      # bnc#694582 - addedd @ as it is allowed in authority part of URI.
      # for details see RFC2616 and RFC2396
      #
      @ValidChars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.:_-/%@"


      # Transform map used for (un)escaping characters in username/password part of an URL.
      # It doesn't contain '%' because this character must be used in a particular
      # order (the first or the last) during processing
      @transform_map_passwd = {
        ";" => "%3b",
        "/" => "%2f",
        "?" => "%3f",
        ":" => "%3a",
        "@" => "%40",
        "&" => "%26",
        "=" => "%3d",
        "+" => "%2b",
        "$" => "%24",
        "," => "%2c",
        " " => "%20"
      }

      # Transform map used for (un)escaping characters in file location part of an URL.
      # It doesn't contain '%' because this character must be used in a particular
      # order (the first or the last) during processing
      @transform_map_filename = {
        ";" => "%3b",
        "?" => "%3f",
        ":" => "%3a",
        "@" => "%40",
        "&" => "%26",
        "=" => "%3d",
        "+" => "%2b",
        "$" => "%24",
        "," => "%2c",
        " " => "%20"
      }

      # Transform map used for (un)escaping characters in query part of a URL.
      # It doesn't contain '%' because this character must be used in a particular
      # order (the first or the last) during processing
      @transform_map_query = {
        ";" => "%3b",
        "?" => "%3f",
        "@" => "%40",
        "+" => "%2b",
        "$" => "%24",
        "," => "%2c",
        " " => "%20"
      }
    end

    # Escape reserved characters in string used as a part of URL (e.g. '%25' => '%', '%40' => '@'...)
    #
    # @param [String] in input string to escape
    # @param transformation map
    # @return [String] unescaped string
    #
    # @example
    #	URL::UnEscapeString ("http%3a%2f%2fsome.nice.url%2f%3awith%3a%2f%24p#ci%26l%2fch%40rs%2f", URL::transform_map_passwd)
    #		-> http://some.nice.url/:with:/$p#ci&l/ch@rs/

    def UnEscapeString(_in, transform)
      transform = deep_copy(transform)
      return "" if _in == nil || _in == ""

      # replace the other reserved characters
      Builtins.foreach(transform) do |tgt, src|
        # replace both upper and lower case escape sequences
        _in = String.Replace(_in, Builtins.tolower(src), tgt)
        _in = String.Replace(_in, Builtins.toupper(src), tgt)
      end 


      # replace % at the end
      _in = String.Replace(_in, "%25", "%")

      _in
    end

    # Escape reserved characters in string used as a part of URL (e.g. '%' => '%25', '@' => '%40'...)
    #
    # @param [String] in input string to escape
    # @param transformation map
    # @return [String] escaped string
    #
    # @example
    #	URL::EscapeString ("http://some.nice.url/:with:/$p#ci&l/ch@rs/", URL::transform_map_passwd)
    #		-> http%3a%2f%2fsome.nice.url%2f%3awith%3a%2f%24p#ci%26l%2fch%40rs%2f

    def EscapeString(_in, transform)
      transform = deep_copy(transform)
      ret = ""

      return ret if _in == nil || _in == ""

      # replace % at first
      ret = Builtins.mergestring(Builtins.splitstring(_in, "%"), "%25")

      # replace the other reserved characters
      Builtins.foreach(transform) do |src, tgt|
        ret = Builtins.mergestring(Builtins.splitstring(ret, src), tgt)
      end 


      ret
    end

    # Tokenize URL
    # @param [String] url URL to be parsed
    # @return URL split to tokens
    # @example Parse("http://name:pass@www.suse.cz:80/path/index.html?question#part") ->
    #     $[
    #         "scheme"  : "http",
    #         "host"    : "www.suse.cz"
    #         "port"    : "80",
    #         "path"    : /path/index.html",
    #         "user"    : "name",
    #         "pass"    : "pass",
    #         "query"   : "question",
    #         "fragment": "part"
    #     ]
    def Parse(url)
      log.debug("url: #{url}")

      # We don't parse empty URLs
      return {} if url == nil || url.empty?

      uri = URI(url)

      tokens = {
        "scheme"  => uri.scheme,
        "host"    => uri.hostname,
        "port"    => uri.port.to_s,
        "path"    => uri.path,
        "user"    => uri.user,
        "pass"    => uri.password,
        "query"   => uri.query,
        "fragment"=> uri.fragment
      }

      if defined? uri.domain
        tokens["domain"] = uri.domain
      end

      Hash[
           tokens.to_a.map{ |k,v|
             [k,v.nil? ? "" : v]
           }
          ]
    end

    # Check URL
    # @param [String] url URL to be checked
    # @return true if correct
    # @see RFC 2396 (updated by RFC 2732)
    # @see also perl-URI: URI(3)
    def Check(url)
      # We don't allow empty URLs
      return false if url == nil || Ops.less_than(Builtins.size(url), 1)

      # We don't allow URLs with spaces
      return false if Builtins.search(url, " ") != nil

      tokens = Parse(url)

      Builtins.y2debug("tokens: %1", tokens)

      # Check "scheme"  : "http"
      if !Builtins.regexpmatch(
          Ops.get_string(tokens, "scheme", ""),
          "^[[:alpha:]]*$"
        )
        return false
      end

      # Check "host"    : "www.suse.cz"
      if !Hostname.CheckFQ(Ops.get_string(tokens, "host", "")) &&
          !IP.Check(Ops.get_string(tokens, "host", "")) &&
          Ops.get_string(tokens, "host", "") != ""
        return false
      end

      # Check "path"    : /path/index.html"

      # Check "port"    : "80"
      if !Builtins.regexpmatch(Ops.get_string(tokens, "port", ""), "^[0-9]*$")
        return false
      end

      # Check "user"    : "name"

      # Check "pass"    : "pass"

      # Check "query"   : "question"

      # Check "fragment": "part"

      true
    end


    # Build URL from tokens as parsed with Parse
    # @param map token as returned from Parse
    # @return [String] url, empty string if invalid data is used to build the url.
    # @see RFC 2396 (updated by RFC 2732)
    # @see also perl-URI: URI(3)
    def Build(tokens)
      tokens = deep_copy(tokens)
      url = ""
      userpass = ""

      Builtins.y2debug("URL::Build(): input: %1", tokens)

      if Builtins.regexpmatch(
          Ops.get_string(tokens, "scheme", ""),
          "^[[:alpha:]]*$"
        )
        # if (tokens["scheme"]:"" == "samba") url="smb";
        # 		else
        url = Ops.get_string(tokens, "scheme", "")
      end
      Builtins.y2debug("url: %1", url)
      if Ops.get_string(tokens, "user", "") != ""
        userpass = URLRecode.EscapePassword(Ops.get_string(tokens, "user", ""))
        Builtins.y2milestone(
          "Escaped username '%1' => '%2'",
          Ops.get_string(tokens, "user", ""),
          userpass
        )
      end
      if Builtins.size(userpass) != 0 &&
          Ops.get_string(tokens, "pass", "") != ""
        userpass = Builtins.sformat(
          "%1:%2",
          userpass,
          URLRecode.EscapePassword(Ops.get_string(tokens, "pass", ""))
        )
      end
      if Ops.greater_than(Builtins.size(userpass), 0)
        userpass = Ops.add(userpass, "@")
      end

      url = Builtins.sformat("%1://%2", url, userpass)
      Builtins.y2debug("url: %1", url)

      if Hostname.CheckFQ(Ops.get_string(tokens, "host", "")) ||
          IP.Check(Ops.get_string(tokens, "host", ""))
        # enclose an IPv6 address in square brackets
        url = IP.Check6(Ops.get_string(tokens, "host", "")) ?
          Builtins.sformat("%1[%2]", url, Ops.get_string(tokens, "host", "")) :
          Builtins.sformat("%1%2", url, Ops.get_string(tokens, "host", ""))
      end
      Builtins.y2debug("url: %1", url)

      if Builtins.regexpmatch(Ops.get_string(tokens, "port", ""), "^[0-9]*$") &&
          Ops.get_string(tokens, "port", "") != ""
        url = Builtins.sformat("%1:%2", url, Ops.get_string(tokens, "port", ""))
      end
      Builtins.y2debug("url: %1", url)

      # path is not empty and doesn't start with "/"
      if Ops.get_string(tokens, "path", "") != "" &&
          !Builtins.regexpmatch(Ops.get_string(tokens, "path", ""), "^/")
        url = Builtins.sformat(
          "%1/%2",
          url,
          URLRecode.EscapePath(Ops.get_string(tokens, "path", ""))
        )
      # patch is not empty and starts with "/"
      elsif Ops.get_string(tokens, "path", "") != "" &&
          Builtins.regexpmatch(Ops.get_string(tokens, "path", ""), "^/")
        while Builtins.substring(Ops.get_string(tokens, "path", ""), 0, 2) == "//"
          Ops.set(
            tokens,
            "path",
            Builtins.substring(Ops.get_string(tokens, "path", ""), 1)
          )
        end
        if Ops.get_string(tokens, "scheme", "") == "ftp"
          url = Builtins.sformat(
            "%1/%%2f%2",
            url,
            Builtins.substring(
              URLRecode.EscapePath(Ops.get_string(tokens, "path", "")),
              1
            )
          )
        else
          url = Builtins.sformat(
            "%1%2",
            url,
            URLRecode.EscapePath(Ops.get_string(tokens, "path", ""))
          )
        end
      end
      Builtins.y2debug("url: %1", url)


      query_map = MakeMapFromParams(Ops.get_string(tokens, "query", ""))

      if Ops.get_string(tokens, "scheme", "") == "smb" &&
          Ops.greater_than(
            Builtins.size(Ops.get_string(tokens, "domain", "")),
            0
          ) &&
          Ops.get(query_map, "workgroup", "") !=
            Ops.get_string(tokens, "domain", "")
        Ops.set(query_map, "workgroup", Ops.get_string(tokens, "domain", ""))

        Ops.set(tokens, "query", MakeParamsFromMap(query_map))
      end

      if Ops.get_string(tokens, "query", "") != ""
        url = Builtins.sformat(
          "%1?%2",
          url,
          URLRecode.EscapeQuery(Ops.get_string(tokens, "query", ""))
        )
      end

      if Ops.get_string(tokens, "fragment", "") != ""
        url = Builtins.sformat(
          "%1#%2",
          url,
          URLRecode.EscapePassword(Ops.get_string(tokens, "fragment", ""))
        )
      end
      Builtins.y2debug("url: %1", url)

      if !Check(url)
        Builtins.y2error("Invalid URL: %1", url)
        return ""
      end

      Builtins.y2debug("URL::Build(): result: %1", url)

      url
    end

    #  * Format URL - truncate the middle part of the directory to fit to the requested lenght.
    #  *
    #  * Elements in the middle of the path specification are replaced by ellipsis (...).
    #  * The result migth be longer that requested size if other URL parts are longer than the requested size.
    #  * If the requested size is greater than size of the full URL then full URL is returned.
    #  * Only path element of the URL is changed the other parts are not modified (e.g. protocol name)
    #  *
    #  * @example FormatURL("http://download.opensuse.org/very/log/path/which/will/be/truncated/target_file", 45)
    # &nbsp;&nbsp;&nbsp;&nbsp;-> "http://download.opensuse.org/.../target_file"
    #  * @example FormatURL("http://download.opensuse.org/very/log/path/which/will/be/truncated/target_file", 60)
    # &nbsp;&nbsp;&nbsp;&nbsp;-> "http://download.opensuse.org/very/.../be/truncated/target_file"
    #  *
    #  * @param tokens parsed URL
    #  * @see Parse should be used to convert URL string to a map (tokens parameter)
    #  * @param len requested maximum lenght of the output string
    #  * @return string Truncated URL
    def FormatURL(tokens, len)
      tokens = deep_copy(tokens)
      ret = Build(tokens)

      # full URL is shorter than requested, no truncation needed
      return ret if Ops.less_or_equal(Builtins.size(ret), len)

      # it's too long, some parts must be removed
      pth = Ops.get_string(tokens, "path", "")
      Ops.set(tokens, "path", "")

      no_path = Build(tokens)
      # size for the directory part
      dir_size = Ops.subtract(len, Builtins.size(no_path))

      # remove the path in the middle
      new_path = String.FormatFilename(pth, dir_size)

      # build the url with the new path
      Ops.set(tokens, "path", new_path)
      Build(tokens)
    end

    # y2milestone("%1", Parse("http://a:b@www.suse.cz:33/ahoj/nekde?neco#blah"));
    # y2milestone("%1", Parse("ftp://www.suse.cz/ah"));
    # y2milestone("%1", Parse("ftp://www.suse.cz:22/ah"));
    # y2milestone("%1", Parse("www.suse.cz/ah"));
    #
    # y2milestone("%1", Check("http://a:b@www.suse.cz:33/ahoj/nekde?neco#blah"));
    # y2milestone("%1", Check("ftp://www.suse.cz/ah"));
    # y2milestone("%1", Check("ftp://www.suse.cz:22/ah"));
    # y2milestone("%1", Check("www.suse.cz/ah"));
    # y2milestone("%1", Check("www.suse.cz ah"));
    # y2milestone("%1", Check(""));
    # y2milestone("%1", Check(nil));

    # Reads list of HTTP params and returns them as map.
    # (Useful also for cd:/, dvd:/, nfs:/ ... params)
    # Neither keys nor values are HTML-unescaped, see UnEscapeString().
    #
    # @param [String] params
    # @return [Hash{String => String}] params
    #
    # @example
    #      MakeMapFromParams ("device=sda3&login=aaa&password=bbb") -> $[
    #              "device"   : "sda3",
    #              "login"    : "aaa",
    #              "password" : "bbb"
    #      ]
    def MakeMapFromParams(params)
      # Error
      if params == nil
        Builtins.y2error("Erroneous (nil) params!")
        return nil 
        # Empty
      elsif params == ""
        return {}
      end

      params_list = Builtins.splitstring(params, "&")

      params_list = Builtins.filter(params_list) do |one_param|
        one_param != "" && one_param != nil
      end

      ret = {}
      eq_pos = nil
      opt = ""
      val = ""

      Builtins.foreach(params_list) do |one_param|
        eq_pos = Builtins.search(one_param, "=")
        if eq_pos == nil
          Ops.set(ret, one_param, "")
        else
          opt = Builtins.substring(one_param, 0, eq_pos)
          val = Builtins.substring(one_param, Ops.add(eq_pos, 1))

          Ops.set(ret, opt, val)
        end
      end

      deep_copy(ret)
    end

    # Returns string made of HTTP params. It's a reverse function to MakeMapFromParams().
    # Neither keys nor values are HTML-escaped, use EscapeString() if needed.
    #
    # @param map <string, string>
    #
    # @see #MakeMapFromParams
    #
    # @example
    #   MakeMapFromParams ($[
    #     "param1" : "a",
    #     "param2" : "b",
    #     "param3" : "c",
    #   ]) -> "param1=a&param2=b&param3=c"
    def MakeParamsFromMap(params_map)
      params_map = deep_copy(params_map)
      # ["key1=value1", "key2=value2", ...] -> "key1=value1&key2=value2"
      Builtins.mergestring(
        # ["key" : "value", ...] -> ["key=value", ...]
        Builtins.maplist(params_map) do |key, value|
          if value == nil
            Builtins.y2warning("Empty value for key %1", key)
            value = ""
          end
          if key == nil || key == ""
            Builtins.y2error("Empty key (will be skipped)")
            next ""
          end
          # "key=value"
          Builtins.sformat("%1=%2", key, value)
        end,
        "&"
      )
    end

    # Hide password in an URL - replaces the password in the URL by 'PASSWORD' string.
    # If there is no password in the URL the original URL is returned.
    # It should be used when an URL is logged to y2log or when it is displayed to user.
    # @param [String] url original URL
    # @return [String] new URL with 'PASSWORD' password or unmodified URL if there is no password
    def HidePassword(url)
      # Url::Build(Url::Parse) transforms the URL too much, see #247249#c41
      # replace ://user:password@ by ://user:PASSWORD@
      subd = Builtins.regexpsub(
        url,
        "(.*)(://[^/:]*):[^/@]*@(.*)",
        "\\1\\2:PASSWORD@\\3"
      )
      subd == nil ? url : subd
    end

    # Hide password token in parsed URL (by URL::Parse()) - the password is replaced by 'PASSWORD' string.
    # Similar to HidePassword() but uses a parsed URL as the input.
    # @param [Hash] tokens input
    # @return [Hash] map with replaced password
    def HidePasswordToken(tokens)
      tokens = deep_copy(tokens)
      ret = deep_copy(tokens)

      # hide the password if it's there
      if Builtins.haskey(ret, "pass") &&
          Ops.greater_than(Builtins.size(Ops.get_string(ret, "pass", "")), 0)
        Ops.set(ret, "pass", "PASSWORD")
      end

      deep_copy(ret)
    end

    publish :variable => :ValidChars, :type => "string"
    publish :variable => :transform_map_passwd, :type => "map <string, string>"
    publish :variable => :transform_map_filename, :type => "map <string, string>"
    publish :variable => :transform_map_query, :type => "map <string, string>"
    publish :function => :UnEscapeString, :type => "string (string, map <string, string>)"
    publish :function => :EscapeString, :type => "string (string, map <string, string>)"
    publish :function => :MakeMapFromParams, :type => "map <string, string> (string)"
    publish :function => :MakeParamsFromMap, :type => "string (map <string, string>)"
    publish :function => :Parse, :type => "map (string)"
    publish :function => :Check, :type => "boolean (string)"
    publish :function => :Build, :type => "string (map)"
    publish :function => :FormatURL, :type => "string (map, integer)"
    publish :function => :HidePassword, :type => "string (string)"
    publish :function => :HidePasswordToken, :type => "map (map)"
  end

  URL = URLClass.new
  URL.main
end
