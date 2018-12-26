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

module Y2Packager
  module LicensesFetchers
    # This class is responsible for obtaining the license and license content
    # of a given product from a RPM package
    class Rpm < Base
      # Return the license text to be confirmed
      #
      # @param lang [String] Language
      #
      # @return [String, nil] Product's license; nil if the product or the license were not found
      def content(lang)
        super

        if package.nil?
          log.info("No package found for #{product_name}")

          return nil
        end

        license_content_for(lang)
      end

      # Return available locales for product's license
      #
      # @return [Array<String>] Language codes ("de_DE", "en_US", etc.)
      def locales
        if package.nil?
          log.error "Error getting license translations: no package found for #{product_name}"

          return []
        end

        @locales ||=
          begin
            tmpdir = Dir.mktmpdir
            package.extract_to(tmpdir)
            # TODO: Use rpm -qpl file.rpm instead?
            license_files = Dir.glob(File.join(tmpdir, "**", "LICENSE.*.TXT"), File::FNM_CASEFOLD)
            license_files.map { |path| path[/LICENSE.(\w*).TXT/i, 1] }.compact
          end
      end

    private

      # Return the license content for a package and language
      #
      # Package is extracted to a work directory. When a license for a language "xx_XX" is not
      # found, it will fallback to "xx".
      #
      # @see license_file
      #
      # @param package [Y2Packager::Package] Product package
      # @param lang    [String] Searched language
      #
      # @return [Array<String, String>, nil] Array containing content and language code
      def license_content_for(lang)
        tmpdir = Dir.mktmpdir

        begin
          package.extract_to(tmpdir)
          license_file = license_path(tmpdir, lang) || fallback_path(tmpdir)

          if license_file.nil?
            log.error("License file not found")

            return
          end

          File.read(license_file)
        ensure
          FileUtils.remove_entry_secure(tmpdir)
        end
      end

      # Return license file path for a given package and language
      #
      # When a license for a language "xx_XX" is not found, it will fallback to "xx".
      #
      # @param directory [String] Directory where licenses were uncompressed
      # @param lang      [String] Searched language
      #
      # @return [Array<String, String>] Array containing the path and language code
      def license_path(directory, lang)
        candidate_langs = [lang]
        candidate_langs << lang.split("_", 2).first if lang
        candidate_langs.uniq!

        log.info("Searching for a #{candidate_langs.join(",")} license translations in #{directory}")

        Dir.glob(
          File.join(directory, "**", "LICENSE.{#{candidate_langs.join(",")}}.TXT"),
          File::FNM_CASEFOLD
        ).first
      end

      # Fallback license file
      FALLBACK_LICENSE_FILE = "LICENSE.TXT".freeze

      def fallback_path(directory)
        log.info("Searching for a fallback #{FALLBACK_LICENSE_FILE} file in #{directory}")

        Dir.glob(
          File.join(directory, "**", FALLBACK_LICENSE_FILE),
          File::FNM_CASEFOLD
        ).first
      end

      # Valid statuses for packages containing licenses
      AVAILABLE_STATUSES = [:available, :selected].freeze

      # Find the latest available/selected product package
      #
      # @return [Y2Packager::Package, nil] Package containing licenses; nil if not found
      def package
        return nil if package_name.nil?

        @package ||=
          Y2Packager::Package
            .find(package_name)
            .compact
            .select { |i| AVAILABLE_STATUSES.include?(i.status) }
            .sort { |a, b| Yast::Pkg.CompareVersions(a.version, b.version) }
            .last
      end

      # Find the package name
      #
      # @return [String, nil] the package name for the product; nil if not found
      def package_name
        return @package_name if @package_name

        package_properties = Yast::Pkg.ResolvableProperties(product_name, :product, "").first || {}

        @package_name = package_properties.fetch("product_package", nil)
      end
    end
  end
end
