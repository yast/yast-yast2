# ------------------------------------------------------------------------------
# Copyright (c) 2018 SUSE LLC, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# ------------------------------------------------------------------------------

require "y2packager/licenses_fetchers/base"

Yast.import "Pkg"

module Y2Packager
  module LicensesFetchers
    # Base class for licenses fetchers based on some kind of license
    # archive.
    #
    # It takes care of looking up the licenses in the unpacked
    # archive and manages a temporary cache directory.
    #
    # The actual unpacking and provisioning of the archive file itself must
    # be done in a derived class.
    class Archive < Base
      # Acceptance is not needed if the file exists
      NO_ACCEPTANCE_FILE = "no-acceptance-needed".freeze

      # Fallback license file
      FALLBACK_LICENSE_FILE = "LICENSE.TXT".freeze

      # Return available locales for product's license
      #
      # @return [Array<String>] Language codes ("de_DE", "en_US", etc.)
      def locales
        return [] if !archive_exists?

        @locales ||=
          begin
            unpack_archive

            license_files = Dir.glob(File.join(archive_dir, "**", "LICENSE.*.TXT"), File::FNM_CASEFOLD)
            # NOTE: despite the use of the case-insensitive flag, the captured group will be
            # returned as it is.
            languages = license_files.map { |path| path[/LICENSE.(\w*).TXT/i, 1] }
            languages << DEFAULT_LANG
            languages.compact.uniq
          end
      end

      # Determine whether the license should be accepted or not
      #
      # @return [Boolean] true if the license acceptance is required
      def confirmation_required?
        unpack_archive

        find_path_for(archive_dir, NO_ACCEPTANCE_FILE).nil?
      end

      # Explicit destructor to clean up temporary dir
      #
      # @param dir [String] Temporary directory where licenses were unpacked
      def self.finalize(dir)
        proc { FileUtils.remove_entry_secure(dir) }
      end

    private

      attr_reader :archive_dir

      # Check if a license archive exists
      #
      # Will be overloaded by the actual implementation.
      #
      # @return [Boolean] True, if an archive exists
      def archive_exists?
        false
      end

      # Unpack license archive
      #
      # The idea is to unpack the archive once and keep the temporary directory.
      #
      # This is only a stub that provides the temporary directory. The
      # actual archive unpacking has to be done by the derived class.
      #
      # @return [String] Archive directory
      def unpack_archive
        return @archive_dir if @archive_dir

        @archive_dir = Dir.mktmpdir("yast-licenses-")
        ObjectSpace.define_finalizer(self, self.class.finalize(@archive_dir))
        @archive_dir
      end

      # Return the license content for a language
      #
      # The license archive is extracted to a temporary directory. When a
      # license for a language "xx_XX" is not found, fall back to "xx".
      #
      # @see license_file
      #
      # @param lang    [String] Language code
      #
      # @return [Array<String, String>, nil] Array containing content and language code
      def license_content_for(lang)
        return nil if !archive_exists?

        unpack_archive

        license_file = license_path(archive_dir, lang) || fallback_path(archive_dir)

        if license_file.nil?
          log.error("#{lang} license file not found for #{product_name}")

          return nil
        end

        File.read(license_file)
      end

      # Return license file path for the given languages
      #
      # When a license for a language "xx_XX" is not found, it will fallback to "xx".
      #
      # @param directory [String] Directory where licenses were unpacked
      # @param lang      [String] Language code
      #
      # @return [String, nil] The first licence path for given languages or nil
      def license_path(directory, lang)
        candidate_langs = [lang]
        candidate_langs << lang.split("_", 2).first if lang
        candidate_langs.uniq!

        log.info("Searching for a #{candidate_langs.join(",")} license translation in #{directory}")

        find_path_for(directory, "LICENSE.{#{candidate_langs.join(",")}}.TXT")
      end

      # Return the fallback license file path
      #
      # Looking for a license file without language code
      #
      # @param directory [String] Directory where licenses were unpacked
      #
      # @return [String, nil] The fallback license path
      def fallback_path(directory)
        log.info("Searching for a fallback #{FALLBACK_LICENSE_FILE} file in #{directory}")

        find_path_for(directory, FALLBACK_LICENSE_FILE)
      end

      # Return the path for the given file in specified directory
      #
      # @param directory [String] Directory where licenses were unpacked
      # @param file      [String] File name (without directory component)
      #
      # @return [String, nil] The file path; nil if was not found
      def find_path_for(directory, file)
        Dir.glob(File.join(directory, "**", file), File::FNM_CASEFOLD).first
      end
    end
  end
end
