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
require "fileutils"
require "y2packager/package"
require "y2packager/release_notes"
require "y2packager/release_notes_content_prefs"
require "y2packager/release_notes_fetchers/base"
require "packages/package_downloader"
require "tmpdir"

Yast.import "Directory"
Yast.import "Pkg"

module Y2Packager
  module ReleaseNotesFetchers
    # This class is able to read release notes from a RPM package
    #
    # Release notes for a product are available in a specific package which provides
    # "release-notes()" for the given product. For instance, a package which provides
    # "release-notes() = SLES" will provide release notes for the SLES product.
    #
    # If more than one product provide release notes for that product, the first
    # one in alphabetical order will be selected.
    #
    # This reader takes care of downloading the release notes package (if any),
    # extracting its content and returning release notes for a given language/format.
    #
    # @see Base
    class Rpm < Base
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
        if release_notes_package.nil?
          log.info "No package containing release notes for #{product.name} was found"
          return nil
        end

        relnotes = extract_release_notes(prefs)
        log.info "Got release notes for #{product.name} from RPM " \
          "#{release_notes_package.name} #{release_notes_package.version} " \
          "with #{prefs}"
        relnotes
      end

      # Return release notes latest version identifier
      #
      # @example Getting release notes version
      #   reader = ReleaseNotesFetchers::Rpm.new(product)
      #   reader.latest_version # => "15.0"
      #
      # @example Not defined product
      #   reader = ReleaseNotesFetchers::Rpm.new(product)
      #   reader.latest_version # => :none
      #
      # @return [String,:none] Package version; :none if no release notes package
      #   was found.
      def latest_version
        return :none if release_notes_package.nil?
        release_notes_package.version
      end

    private

      # Return the release notes package for a given product
      #
      # This method queries libzypp asking for the package which contains release
      # notes for the given product. It relies on the `release-notes()` tag.
      # If more than one product provide release notes for that product, the first
      # one in alphabetical order will be selected.
      #
      # @return [Package,nil] Package containing the release notes; nil if not found
      def release_notes_package
        return @release_notes_package if @release_notes_package
        provides = Yast::Pkg.PkgQueryProvides("release-notes()")
        release_notes_packages = provides.map(&:first).uniq
        package_name = release_notes_packages.sort.find do |name|
          dependencies = Yast::Pkg.ResolvableDependencies(name, :package, "").first["deps"]
          dependencies.any? do |dep|
            dep["provides"].to_s.match(/release-notes\(\)\s*=\s*#{product.name}\s*/)
          end
        end
        return nil if package_name.nil?

        @release_notes_package = find_package(package_name)
      end

      # Valid statuses for packages containing release notes
      AVAILABLE_STATUSES = [:available, :selected].freeze

      # Find the latest available/selected package containing release notes
      #
      # @return [Package,nil] Package containing release notes; nil if not found
      def find_package(name)
        Y2Packager::Package
          .find(name)
          .select { |i| AVAILABLE_STATUSES.include?(i.status) }
          .sort { |a, b| Yast::Pkg.CompareVersions(a.version, b.version) }
          .last
      end

      # Return release notes instance
      #
      # @param prefs [ReleaseNotesContentPrefs] Content preferences
      # @return [ReleaseNotes,nil] Release notes for given arguments
      def extract_release_notes(prefs)
        content, lang = release_notes_content(release_notes_package, prefs)
        return nil if content.nil?

        Y2Packager::ReleaseNotes.new(
          product_name: product.name,
          content:      content,
          user_lang:    prefs.user_lang,
          lang:         lang,
          format:       prefs.format,
          version:      release_notes_package.version
        )
      end

      # Return release notes content for a package, language and format
      #
      # Release notes are downloaded and extracted to work directory.  When
      # release notes for a language "xx_XX" are not found, it will fallback to
      # "xx".
      #
      # @param package [String] Release notes package name
      # @param prefs   [ReleaseNotesContentPrefs] Content preferences
      # @return [Array<String,String>] Array containing content and language code
      # @see release_notes_file
      def release_notes_content(package, prefs)
        tmpdir = Dir.mktmpdir
        begin
          package.extract_to(tmpdir)
          file, lang = release_notes_file(tmpdir, prefs)
          file ? [File.read(file), lang] : nil
        ensure
          FileUtils.remove_entry_secure(tmpdir)
        end
      end

      # Return release notes file path for a given package, language and format
      #
      # Release notes are downloaded and extracted to work directory.  When
      # release notes for a language "xx_XX" are not found, it will fallback to
      # "xx".
      #
      # @param directory [String] Directory where release notes were uncompressed
      # @param prefs     [ReleaseNotesContentPrefs] Content preferences
      # @return [Array<String,String>] Array containing path and language code
      def release_notes_file(directory, prefs)
        langs = [prefs.user_lang]
        langs << prefs.user_lang.split("_", 2).first if prefs.user_lang.include?("_")
        langs << prefs.fallback_lang

        path = Dir.glob(
          File.join(directory, "**", "RELEASE-NOTES.{#{langs.join(",")}}.#{prefs.format}")
        ).first
        return nil if path.nil?
        [path, path[/RELEASE-NOTES\.(.+)\.#{prefs.format}\z/, 1]] if path
      end
    end
  end
end
