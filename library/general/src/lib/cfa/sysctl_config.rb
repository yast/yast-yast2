# Copyright (c) [2019-2020] SUSE LLC
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

require "yast"
require "yast2/execute"
require "cfa/sysctl"
require "cfa/conflict_report"

Yast.import "FileUtils"

module CFA
  # CFA based API to adjust the sysctl tool configuration
  #
  # This class does not modify the running kernel configuration. It just writes
  # the desired values into the configuration file ({PATH}).
  # Despite the class Sysctl this class also takes care about entries in
  #   /run/sysctl.d,
  #   /etc/sysctl.d
  #   /usr/local/lib/sysctl.d
  #   /usr/lib/sysctl.d
  #   /lib/sysctl.d
  #   /etc/sysctl.conf
  # and inform the user if his settings will be overruled by setting in
  # other files.
  #
  # @example Enabling IPv4 forwarding
  #   sysctl = SysctlConfig.new
  #   sysctl.forward_ipv4 = true
  #   sysctl.save
  class SysctlConfig
    include Yast::Logger

    PATHS = [
      "/run/sysctl.d",
      "/etc/sysctl.d",
      "/usr/local/lib/sysctl.d",
      "/usr/lib/sysctl.d",
      "/lib/sysctl.d",
      "/etc/sysctl.conf"
    ].freeze
    private_constant :PATHS

    YAST_CONFIG_PATH = Sysctl::PATH
    private_constant :YAST_CONFIG_PATH

    class << self
      def define_attr(attr)
        define_method attr do
          file = files.reverse.find do |f|
            f.present?(attr)
          end
          return file.public_send(attr) if file

          yast_config_file.public_send(attr)
        end

        define_method "#{attr}=" do |value|
          yast_config_file.public_send("#{attr}=", value)
        end
      end
    end

    Sysctl.known_attributes.each { |a| define_attr(a) }

    def load
      files.each(&:load)
    end

    # Saving all sysctl settings
    #
    def save
      yast_config_file&.save
    end

    # Whether there is a conflict with given attributes
    #
    # @param only [Array<Symbol>] attributes to check
    # @param show_information [Boolean] showing a popup if it is conflicting
    # @return [Boolean] true if any conflict is found; false otherwise
    def conflict?(only: [], show_information: true)
      return false if yast_config_file.empty?

      conflicting_attrs = Sysctl::ATTRIBUTES.keys
      conflicting_attrs &= only unless only.empty?
      conflicts = {}
      higher_precedence_files.each do |file|
        # Checking all "higher" files if their values overrule the current
        # YAST settings.
        conflict_values = yast_config_file.conflicts(file) & conflicting_attrs
        conflicts[file.file_path] = conflict_values unless conflict_values.empty?
      end

      # Transform into real tags
      conflicts.each do |file, tags|
        conflicts[file] = tags.map { |t| Sysctl::ATTRIBUTES[t.to_sym] }
      end

      if !conflicts.empty?
        log.warn("It could be that #{YAST_CONFIG_PATH} will not be written.")
        log.warn("There are conflicts in sysctl files: #{conflicts}.")
        ConfictReport.report(conflicts) if show_information
      end

      !conflicts.empty?
    end

    def files
      @files ||= config_paths.map { |file| Sysctl.new(file_path: file) }
    end

  private

    def yast_config_file
      @yast_config_file ||= files.find { |f| f.file_path == YAST_CONFIG_PATH }
    end

    def lower_precedence_files
      @lower_precedence_files ||= files[0...yast_config_file_idx]
    end

    def higher_precedence_files
      @higher_precedence_files ||= files[(yast_config_file_idx + 1)..]
    end

    def config_paths
      paths = PATHS.each_with_object([YAST_CONFIG_PATH]) do |path, all|
        all.concat(file_paths_in(path))
      end

      paths.uniq! { |f| File.basename(f) }
      # Sort files lexicographic
      paths.sort_by! { |f| File.basename(f) }

      # Prepend the kernel configuration file
      paths.unshift(boot_config_path) unless boot_config_path.empty?

      paths
    end

    def file_paths_in(path)
      if Yast::FileUtils.IsFile(path)
        [path]
      elsif Yast::FileUtils.IsDirectory(path)
        Yast::SCR.Read(Yast::Path.new(".target.dir"), path)
          .select { |f| f.end_with?(".conf") } # according to 'sysctl.conf' manpage, only .conf files are considered
          .map { |f| File.join(path, f) }
      else
        log.debug("Ignoring not valid path: #{path}")

        []
      end
    end

    def boot_config_path
      return @boot_config_path if @boot_config_path

      @boot_config_path = if kernel_version.empty?
        ""
      else
        "/boot/sysctl.conf-#{kernel_version}"
      end
    end

    def boot_config_file
      @boot_config_file ||= files.find { |f| f.file_path == boot_config_path }
    end

    def kernel_version
      @kernel_version ||= Yast::Execute.on_target.stdout("/usr/bin/uname", "-r").to_s.chomp
    end

    def yast_config_file_idx
      @yast_config_file_idx ||= files.find_index { |f| f == yast_config_file }
    end
  end
end
