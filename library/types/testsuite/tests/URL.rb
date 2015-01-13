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
# File:	XXXXXX
# Package:	Configuration of network
# Summary:	XXXXXX
# Author:	Michal Svec <msvec@suse.cz>
#
# $Id$
module Yast
  class URLClient < Client
    def main
      Yast.include self, "testsuite.rb"
      @READ = { "target" => { "tmpdir" => "/tmp" } }
      TESTSUITE_INIT([@READ], nil)

      Yast.import "URL"

      TEST(lambda do
        URL.Parse(
          "http://name:pass@www.suse.cz:80/path/index.html?question#part"
        )
      end, [], nil)

      TEST(->() { URL.EscapeString(nil, URL.transform_map_passwd) }, [], nil)
      TEST(->() { URL.EscapeString("", URL.transform_map_passwd) }, [], nil)
      TEST(->() { URL.EscapeString("abcd", URL.transform_map_passwd) }, [], nil)
      TEST(->() { URL.EscapeString("abcd%", URL.transform_map_passwd) }, [], nil)
      TEST(->() { URL.EscapeString("ab%c$d", URL.transform_map_passwd) }, [], nil)
      TEST(->() { URL.EscapeString(" %$ ", URL.transform_map_passwd) }, [], nil)
      TEST(->() { URL.EscapeString("_<>{}", URL.transform_map_passwd) }, [], nil)
      TEST(->() { URL.EscapeString("%", URL.transform_map_passwd) }, [], nil)

      TEST(->() { URL.UnEscapeString(nil, URL.transform_map_passwd) }, [], nil)
      TEST(->() { URL.UnEscapeString("", URL.transform_map_passwd) }, [], nil)
      TEST(->() { URL.UnEscapeString("abcd", URL.transform_map_passwd) }, [], nil)
      TEST(->() { URL.UnEscapeString("ab%2fcd%25", URL.transform_map_passwd) }, [], nil)
      TEST(->() { URL.UnEscapeString("ab%40%25", URL.transform_map_passwd) }, [], nil)
      TEST(->() { URL.UnEscapeString("%40", URL.transform_map_passwd) }, [], nil)
      TEST(->() { URL.UnEscapeString("_<>{}", URL.transform_map_passwd) }, [], nil)

      # parse->build must return the orginal value
      TEST(lambda do
        URL.Build(
          URL.Parse(
            "http://name:pass@www.suse.cz:80/path/index.html?question#part"
          )
        )
      end, [], nil)

      # escaped values are built using lower case characters so there might be a change
      TEST(lambda do
        URL.Build(
          URL.Parse(
            "http://na%40me:pa%3F%3fss@www.suse.cz:80/path/index.html?question#part"
          )
        )
      end, [], nil)

      TEST(->() { test }, [], nil)

      TEST(lambda do
        URL.Build(
          {
            "scheme" => "ftp",
            "host"   => "ftp.example.com",
            "path"   => "path/to/dir"
          }
        )
      end, [], nil)
      TEST(lambda do
        URL.Build(
          {
            "scheme" => "ftp",
            "host"   => "ftp.example.com",
            "path"   => "/path/to/dir"
          }
        )
      end, [], nil)
      TEST(lambda do
        URL.Build(
          {
            "scheme" => "ftp",
            "host"   => "ftp.example.com",
            "path"   => "//path/to/dir"
          }
        )
      end, [], nil)
      TEST(lambda do
        URL.Build(
          {
            "scheme" => "ftp",
            "host"   => "ftp.example.com",
            "path"   => "///path/to/dir"
          }
        )
      end, [], nil)
      TEST(lambda do
        URL.Build(
          {
            "scheme" => "ftp",
            "host"   => "ftp.example.com",
            "path"   => "///path/to/dir",
            "query"  => "param1=val1&param2=val2"
          }
        )
      end, [], nil)

      # bnc #446395 - non-ASCII chars in path must be escaped
      TEST(lambda do
        URL.Build(
          {
            "scheme" => "dir",
            "path"   => "/path/to/\u011B\u0161\u010D\u0159\u017E\u00FD\u00E1\u00ED\u00E9/dir"
          }
        )
      end, [], nil)

      # IPv6 tests
      TEST(lambda do
        URL.Build(
          {
            "scheme" => "ftp",
            "host"   => "2001:de8:0:f123::1",
            "path"   => "///path/to/dir"
          }
        )
      end, [], nil)
      TEST(lambda do
        URL.Build(
          {
            "scheme" => "http",
            "host"   => "2001:de8:0:f123::1",
            "path"   => "///path/to/dir",
            "port"   => "8080"
          }
        )
      end, [], nil)
      TEST(->() { URL.Parse("http://[2001:de8:0:f123::1]/path/to/dir") }, [], nil)
      TEST(lambda do
        URL.Parse("http://user:password@[2001:de8:0:f123::1]:8080/path/to/dir")
      end, [], nil)
      TEST(lambda do
        URL.Build(
          URL.Parse(
            "http://user:password@[2001:de8:0:f123::1]:8080/path/to/dir"
          )
        )
      end, [], nil)

      # smb:// tests
      @smb_url = "smb://username:passwd@servername/share/path/on/the/share?mountoptions=ro&workgroup=group"
      TEST(->() { URL.Parse(@smb_url) }, [], nil)
      # parse->build must return the orginal value
      TEST(->() { URL.Build(URL.Parse(@smb_url)) == @smb_url }, [], nil)
      # bnc#491482
      TEST(lambda do
        URL.Build(
          {
            "domain" => "workgroup",
            "host"   => "myserver.com",
            "pass"   => "passwd",
            "path"   => "/share$$share/path/on/the/share",
            "scheme" => "smb",
            "user"   => "username"
          }
        )
      end, [], nil)

      TEST(->() { URL.Build(URL.Parse("dir:///")) }, [], nil)

      @long_url = "http://download.opensuse.org/very/log/path/which/will/be/truncated/target_file"

      # no truncation needed
      TEST(->() { URL.FormatURL(URL.Parse(@long_url), 200) }, [], nil)

      # request too short result
      TEST(->() { URL.FormatURL(URL.Parse(@long_url), 15) }, [], nil)

      TEST(->() { URL.FormatURL(URL.Parse(@long_url), 45) }, [], nil)
      TEST(->() { URL.FormatURL(URL.Parse(@long_url), 65) }, [], nil) 

      # EOF

      nil
    end

    def test
      # change the password in the URL
      m = URL.Parse(
        "http://name:pass@www.suse.cz:80/path/index.html?question#part"
      )
      Ops.set(m, "user", "user@domain")
      URL.Build(m)
    end
  end
end

Yast::URLClient.new.main
