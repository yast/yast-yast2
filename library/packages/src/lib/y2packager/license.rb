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
require "digest"

module Y2Packager
  # Represent a License which could be the same for multiple products.
  #
  # This class stores the license ID and the traslated content of the license
  # for different languages.
  class License
    DEFAULT_LANG = "en_US".freeze
    # @return [String] License unique identifier
    attr_reader :id

    # @return [Boolean] whether the license has been accepted or not
    attr_reader :accepted

    # @retrun [Hash<String, String>] language -> content
    attr_reader :translations

    alias_method :accepted?, :accepted

    # Constructor
    #
    # @param options [Hash<String, String>]
    def initialize(options = {})
      @id = id_for(options)
      @translations = { DEFAULT_LANG => options[:content] }
    end

    # Return the license translated content for the given language
    #
    # @param [String] language
    # @return [String,nil] the license translated content or nil if not found
    def content_for(lang = DEFAULT_LANG)
      translations[lang]
    end

    # Add the license translated content for the given language
    #
    # @param lang [String]
    # @param content [String]
    # @return [String,nil] the license translated content or nil if not found
    def add_content_for(lang, content)
      @translations[lang] = content
    end

    # Set the license as accepted
    def accept!
      @accepted = true
    end

    # Set the license as rejected
    def reject!
      @accepted = false
    end

  private

    # Generate the license unique identifier based on the given options.
    # Currently the id is obtained using the MD5 digest of te license's
    # content (in the default language).
    #
    # @param options [Hash<String,String>] License map options
    # @return [String] MD5 digest of the license's content
    def id_for(options)
      Digest::MD5.hexdigest(options[:content])
    end
  end
end
