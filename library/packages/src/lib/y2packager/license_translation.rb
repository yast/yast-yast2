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

require "yast"

module Y2Packager
  # This class is responsible for storing the different license translations.
  class LicenseTranslation
    # @return [String] Content Language
    attr_reader :lang
    attr_reader :content

    # Constructor
    #
    # @param language [String]
    # @param content [String] of the license for the given language
    def initialize(language:, content:)
      @lang = language
      @content = content
    end
  end
end
