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

module Y2Packager
  # Content preferences for release notes
  #
  # @!attribute [rw] user_lang
  #   @return [String] User preferred language
  # @!attribute [rw] fallback_lang
  #   @return [Symbol] Language to use if release notes for user_lang are not available
  # @!attribute [rw] format
  #   @return [Symbol] Release notes format (:txt or :rtf)
  ReleaseNotesContentPrefs = Struct.new(:user_lang, :fallback_lang, :format) do
    # @return [String] Human readable representation of content preferences
    def to_s
      "content preferences: language '#{user_lang}', fallback language: '#{fallback_lang}', "\
        "and format '#{format}'"
    end
  end
end
