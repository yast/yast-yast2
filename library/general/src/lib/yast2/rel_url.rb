# Copyright (c) [2021] SUSE LLC
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

require "uri"

module Yast2
  # Class for working with relative URLs ("relurl://")
  class RelURL
    attr_reader :base, :relative

    # Is the URL a relative URL?
    #
    # @param url [String, URI] the URL
    # @return [Boolean] `true` if the URL uses the "relurl" schema, otherwise `false`
    def self.relurl?(url)
      URI(url).scheme == "relurl"
    end

    # Create RelURL object with URL relative to the installation repository
    #
    # @param rel_url [String, URI] the relative URL
    # @return [RelURL]
    #
    # @note Works properly only during installation/upgrade, do not use
    #   in an installed system.
    def self.from_installation_repository(rel_url)
      base_url = Yast::InstURL.installInf2Url("")
      new(base_url, rel_url)
    end

    # Constructor
    #
    # @param base_url [String,URI] the base URL
    # @param rel_url [String,URI] the relative URL, it should use the "relurl://"
    #  schema otherwise the base URL is ignored
    def initialize(base_url, rel_url)
      @base = import_url(base_url)
      @relative = import_url(rel_url)
    end

    # Build and absolute URL
    #
    # @param path [String,nil] optional URL subpath
    # @return [URI] the absolute URL
    #
    # @note It internally uses the Ruby `File.expand_path` function which
    # also evaluates the parent directory path ("../") so it is possible
    # to go up in the tree using the "relurl://../foo" or the "../foo" path
    # parameter.
    def absolute_url(path = nil)
      if (!relative.to_s.empty? && !RelURL.relurl?(relative)) || base.to_s.empty?
        ret = relative.dup
        relative_url = URI("")
      else
        ret = base.dup
        relative_url = relative.dup
      end

      relative_path = relative_url.path
      relative_path = File.join(relative_path, path) if path && !path.empty?

      base_path = ret.path
      if !base_path.empty? || !relative_path.empty?
        # the path would be expanded from the current working directory
        # by File.expand_path if the base path is not absolute
        base_path.prepend("/") if !base_path.start_with?("/")

        # escape the "~"" character, it is treated as a home directory name by File.expand_path,
        # moreover it raises ArgumentError if that user does not exist in the system
        relative_path.gsub!("~", "%7E")
        # the relative path really needs to be relative, remove the leading slash(es)
        relative_path.sub!(/\A\/+/, "")

        ret.path = File.expand_path(relative_path, base_path)
      end

      export_url(ret)
      ret
    end

  private

    # a helper method for importing an URL,
    # it creates a copy of the input object and pre-processes the
    # "file://" and "relurl://" URLs
    def import_url(url)
      ret = URI(url).dup

      # move the host part to the path part for some URL types
      if ["file", "relurl"].include?(ret.scheme) && ret.host
        # URI requires absolute path
        ret.path = File.join("/", ret.host, ret.path)
        ret.host = nil
      end

      ret
    end

    # adjust the result if it is a "file://" URL
    def export_url(url)
      return if url.scheme != "file" && !url.host.nil? && !url.host.empty?

      path = url.path.sub(/\A\/+/, "").split("/")
      url.host = path.shift

      rest = File.join(path)
      rest.prepend("/") unless path.empty?
      url.path = rest
    end
  end
end
