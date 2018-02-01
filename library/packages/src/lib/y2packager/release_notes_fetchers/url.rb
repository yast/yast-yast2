# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "yast"
require "y2packager/release_notes"
require "y2packager/release_notes_fetchers/base"
require "tmpdir"

Yast.import "Pkg"
Yast.import "Proxy"
Yast.import "String"

module Y2Packager
  module ReleaseNotesFetchers
    # This class reads release notes from the relnotes_url product property
    #
    # The code was extracted from the old version of the InstDownloadReleaseNotesClient
    # and adapted. See https://github.com/yast/yast-installation/blob/62596684d6de242667a0957765c85712874e77ef/src/lib/installation/clients/inst_download_release_notes.rb
    #
    # @see Base
    class Url < Base
      class << self
        # Enable downloading release notes
        #
        # This method is intended to be used during testing.
        def enable!
          @enabled = true
        end

        # Disable downloading release notes due to communication errors
        def disable!
          @enabled = false
        end

        # Determine if release notes would be downloaded
        #
        # @return [Boolean]
        # @see disable!
        def enabled?
          return true if @enabled.nil?
          @enabled
        end

        # Blacklist of URLs that failed to download and should not be retried
        #
        # @return [Array<String>] List of URLs
        def blacklist
          @blacklist ||= []
        end

        # Add an URL to the blacklist
        #
        # @param url [String] URL
        def add_to_blacklist(url)
          blacklist << url
        end

        # Determine whether an URL is blacklisted or not
        #
        # @return [Boolean]
        def blacklisted?(url)
          blacklist.include?(url)
        end

        # Clear products blackist
        def clear_blacklist
          blacklist.clear
        end
      end

      # When cURL returns one of those codes, the download won't be retried
      # @see man curl
      CURL_GIVE_UP_RETURN_CODES = {
        5  => "Couldn't resolve proxy.",
        6  => "Couldn't resolve host.",
        7  => "Failed to connect to host.",
        28 => "Operation timeout."
      }.freeze

      # Get release notes for the given product
      #
      # Release notes are downloaded and extracted to work directory.  When
      # release notes for a language "xx_XX" are not found, it will fallback to
      # "xx".
      #
      # @param prefs [ReleaseNotesContentPrefs] Content preferences
      # @return [String,nil] Release notes or nil if a release notes were not found
      #   (no package providing release notes or notes not found in the package)
      def release_notes(prefs)
        if !self.class.enabled?
          log.info("Skipping release notes download due to previous download issues")
          return nil
        end

        if self.class.blacklisted?(relnotes_url)
          log.info("Skipping release notes download for #{product.name} due to previous issues")
          return nil
        end

        if !relnotes_url_valid?
          log.warn("Skipping release notes download for #{product.name}: '#{relnotes_url}'")
          return nil
        end

        relnotes = fetch_release_notes(prefs)

        if relnotes
          log.info "Got release notes for #{product.name} from URL #{relnotes_url} " \
            "with #{prefs}"
          return relnotes
        end

        log.warn("Release notes for product #{product.name} not found. " \
                 "Blacklisting #{relnotes_url}...")
        self.class.add_to_blacklist(relnotes_url)
        nil
      end

      # Return release notes latest version identifier
      #
      # Release notes that lives in relnotes_url are considered always to be the
      # latest version, hence this method always returns :latest.
      #
      # @return [:latest]
      def latest_version
        :latest
      end

    private

      # Return the release notes instance
      #
      # It relies on #release_notes_content to get release notes content.
      #
      # @param prefs [ReleaseNotesContentPrefs] Content preferences
      # @return [ReleaseNotes,nil] Release notes or nil if a release notes were not found
      # @see release_notes_content
      def fetch_release_notes(prefs)
        content, lang = release_notes_content(prefs)
        return nil if content.nil?

        Y2Packager::ReleaseNotes.new(
          product_name: product.name,
          content:      content,
          user_lang:    prefs.user_lang,
          lang:         lang,
          format:       prefs.format,
          version:      :latest
        )
      end

      # Search for release notes content
      #
      # @param prefs [ReleaseNotesContentPrefs] Content preferences
      # @return [String,nil] Return release notes content or nil if it release
      #   notes were not found
      def release_notes_content(prefs)
        langs = [prefs.user_lang]
        langs << prefs.user_lang.split("_", 2).first if prefs.user_lang.include?("_")
        langs << prefs.fallback_lang

        langs.uniq.each do |lang|
          content = release_notes_content_for_lang_and_format(lang, prefs.format)
          return [content, lang] if content
        end

        nil
      end

      # Return release notes content for a given language and format
      #
      # @return [String,nil] Return release notes content or nil if it release
      def release_notes_content_for_lang_and_format(lang, format)
        # If there is an index and the language is not indexed
        return nil unless release_notes_index.empty? || indexed_release_notes_for?(lang, format)

        # Where we want to store the downloaded release notes
        tmpfile = Tempfile.new("relnotes-")

        return nil unless curl_download(release_notes_file_url(lang, format), tmpfile.path)

        log.info("Release notes downloaded successfully")
        File.read(tmpfile.path)
      ensure
        if tmpfile
          tmpfile.close
          tmpfile.unlink
        end
      end

      # Determine whether the relnotes URL is valid
      #
      # @return [Boolean]
      def relnotes_url_valid?
        if relnotes_url.nil? || relnotes_url.empty?
          log.error "No release notes URL for #{product.name}"
          return false
        end

        if relnotes_url.rindex("/").nil?
          log.error "Broken URL for release notes: #{relnotes_url}"
          return false
        end

        true
      end

      # Return release notes URL from libzypp
      #
      # @return [String] Release notes URL
      def relnotes_url
        return @relnotes_url if @relnotes_url
        data = Yast::Pkg.ResolvableProperties(product.name, :product, "").first
        @relnotes_url = data["relnotes_url"]
      end

      # Return release notes URL
      #
      # @return [String] Release notes full URL
      # @see #release_notes_filename
      def release_notes_file_url(user_lang, format)
        File.join(relnotes_url_base, release_notes_file(user_lang, format))
      end

      # Return release notes base URL
      #
      # @return [String] Release notes base URL
      def relnotes_url_base
        return @relnotes_url_base if @relnotes_url_base
        pos = relnotes_url.rindex("/")
        @relnotes_url_base = relnotes_url[0, pos]
      end

      # Return release notes filename including language and format
      #
      # @return [String] Release notes filename
      def release_notes_file(user_lang, format)
        "RELEASE-NOTES.#{user_lang}.#{format}"
      end

      # curl proxy options
      #
      # @return [String] to be interpolated in a .target.bash command, unquoted
      def curl_proxy_args
        return @curl_proxy_args if @curl_proxy_args
        @curl_proxy_args = ""
        # proxy should be set by inst_install_inf if set via Linuxrc
        Yast::Proxy.Read
        # Test if proxy works

        return @curl_proxy_args unless Yast::Proxy.enabled
        # it is enough to test http proxy, release notes are downloaded via http
        proxy_ret = Yast::Proxy.RunTestProxy(
          Yast::Proxy.http,
          "",
          "",
          Yast::Proxy.user,
          Yast::Proxy.pass
        )

        http_ret = proxy_ret.fetch("HTTP", {})
        if http_ret.fetch("tested", true) == true && http_ret.fetch("exit", 1) == 0
          user_pass = Yast::Proxy.user != "" ? "#{Yast::Proxy.user}:#{Yast::Proxy.pass}" : ""
          proxy = "--proxy #{Yast::Proxy.http}"
          proxy << " --proxy-user '#{user_pass}'" unless user_pass.empty?
        end

        @curl_proxy_args = proxy
      end

      # Release notes index for the given product
      #
      # @return [Array<String>] Index containing the list of release notes files
      # @see #download_release_notes_index
      def release_notes_index
        return @release_notes_index if @release_notes_index
        @release_notes_index = download_release_notes_index(relnotes_url_base) || []
      end

      # Determine whether the release notes index contains an entry for the given
      # language and format
      #
      # @return [Boolean]
      def indexed_release_notes_for?(user_lang, format)
        release_notes_index.include?(release_notes_file(user_lang, format))
      end

      # Download of index of release notes for a specific product
      #
      # @param url_base URL pointing to directory with the index
      # @return [Array<String>,nil] filenames, nil if not found
      def download_release_notes_index(url_base)
        url_index = url_base + "/directory.yast"
        log.info("Index with available files: #{url_index}")
        tmpfile = Tempfile.new("directory.yast-")

        # download the index with much shorter time-out
        ok = curl_download(url_index, tmpfile.path, max_time: 30)

        if ok
          log.info("Release notes index downloaded successfully")
          index_file = File.read(tmpfile.path)
          if index_file.nil? || index_file.empty?
            log.info("Release notes index empty, not filtering further downloads")
            nil
          else
            rn_index = index_file.split("\n")
            log.info("Index of RN files at the server: #{rn_index}")
            rn_index
          end
        elsif ok.nil?
          nil
        else
          log.info "Downloading index failed, trying all files according to selected language"
          nil
        end
      ensure
        tmpfile.close
        tmpfile.unlink
      end

      # Download *url* to *filename*
      #
      # May disable release notes downloading by calling .disable!.
      #
      # @return [Boolean,nil] true: success, false: failure, nil: failure+dont retry
      def curl_download(url, filename, max_time: 300)
        return nil unless self.class.enabled?
        cmd = Yast::Builtins.sformat(
          "/usr/bin/curl --location --verbose --fail --max-time %6 " \
          "--connect-timeout 15  %1 '%2' --output '%3' > '%4/%5' 2>&1",
          curl_proxy_args,
          url,
          Yast::String.Quote(filename),
          Yast::String.Quote(Yast::Directory.logdir),
          "curl_log",
          max_time
        )
        ret = Yast::SCR.Execute(Yast::Path.new(".target.bash"), cmd)
        log.info("#{cmd.sub(curl_proxy_args, "--proxy-user @PROXYPASSWORD@")} returned #{ret}")
        reason = CURL_GIVE_UP_RETURN_CODES[ret]
        if reason
          log.info "Communication with server failed (#{reason}), skipping further attempts."
          self.class.disable!
          return nil
        end
        ret == 0
      end
    end
  end
end
