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
require "y2packager/release_notes_store"
require "y2packager/release_notes_fetchers/rpm"
require "y2packager/release_notes_fetchers/url"
require "y2packager/release_notes_content_prefs"

Yast.import "Directory"
Yast.import "Pkg"

module Y2Packager
  # This class is able to read release notes for a given product
  #
  # It can use two different strategies or backends:
  #
  # * {ReleaseNotesFetchers::Rpm} which gets release notes from a package.
  # * {ReleaseNotesFetchers::Url} which gets release notes from an external URL
  #   (using the relnotes_url property from the given product).
  #
  # ### How it works
  #
  # We can distinguish two different case:
  #
  # * When the system *is registered*: release notes will be obtained from RPM packages.
  #   If release notes are not found there, it will fall back to the
  #   "relnotes_url" product property.  This behaviour covers the case in which
  #   you are installing behind a SMT but without access to Internet.
  # * When the system *is not registered*: it will work the other way around, trying
  #   first relnotes_url and falling back to RPM packages.
  #
  # ### Cached release notes
  #
  # Release notes are stored using an instance of `Y2Packager::ReleaseNotesStore`.
  # When trying to read a product release notes for second time, this class will try to fetch
  # the latest version (determined by ReleaseNotesFetchers::Rpm#latest_version or
  # ReleaseNotesFetchers::Url#latest_version from the store). If release notes are not there,
  # or the stored version is outdated (maybe a new package is now available), it will
  # try to get that version.
  #
  # Take into account that, when using the relnotes_url property, an URL that already
  # failed will not be retried again. See ReleaseNotesFetchers::Url for further details.
  class ReleaseNotesReader
    include Yast::Logger

    # Product to get release notes for
    attr_reader :product

    # Constructor
    #
    # @param product             [Product]           Product to get release notes for
    # @param release_notes_store [ReleaseNotesStore] Release notes store to cache data
    def initialize(product, release_notes_store = nil)
      @release_notes_store = release_notes_store
      @product = product
    end

    # Fallback language
    FALLBACK_LANG = "en".freeze

    # Get release notes for a given product
    #
    # @param user_lang [String] Release notes language (falling back to "en")
    # @param format    [Symbol] Release notes format (:txt or :rtf)
    # @return [String,nil] Release notes or nil if release notes were not found
    #   (no package providing release notes or notes not found in the package)
    def release_notes(user_lang: "en_US", format: :txt)
      readers =
        # registered system: get relnotes from RPMs and fallback to relnotes_url property
        if registered?
          [
            ReleaseNotesFetchers::Rpm.new(product),
            ReleaseNotesFetchers::Url.new(product)
          ]
        else # unregistered system: try relnotes first and fallback to RPMs
          [
            ReleaseNotesFetchers::Url.new(product),
            ReleaseNotesFetchers::Rpm.new(product)
          ]
        end

      prefs = ReleaseNotesContentPrefs.new(user_lang, FALLBACK_LANG, format)
      readers.each do |reader|
        rn = release_notes_via_reader(reader, prefs)
        return rn if rn
      end

      nil
    end

    # Get release notes for a given product using a reader instance
    #
    # @param reader [ReleaseNotesFetchers::Rpm,ReleaseNotesFetchers::Url] Release notes reader
    # @param prefs  [ReleaseNotesContentPrefs] Content preferences
    # @return [String,nil] Release notes or nil if release notes were not found
    #   (no package providing release notes or notes not found in the package)
    # @see ReleaseNotesFetchers::Rpm#release_notes
    # @see ReleaseNotesFetchers::Url#release_notes
    def release_notes_via_reader(reader, prefs)
      from_store = release_notes_store.retrieve(
        product.name, prefs.user_lang, prefs.format, reader.latest_version
      )

      if from_store
        log.info "Release notes for #{product.name} were found"
        return from_store
      end

      release_notes = reader.release_notes(prefs)

      if release_notes
        log.info "Release notes for #{product.name} were found"
        release_notes_store.store(release_notes)
      end

      release_notes
    end

  private

    # Determine whether the system is registered
    #
    # @return [Boolean]
    def registered?
      require "registration/registration"
      Registration::Registration.is_registered?
    rescue LoadError
      false
    end

    # Release notes store
    #
    # This store is used to cache already retrieved release notes.
    #
    # @return [ReleaseNotesStore] Release notes store
    def release_notes_store
      @release_notes_store ||= Y2Packager::ReleaseNotesStore.current
    end
  end
end
