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

Yast.import "FileUtils"
Yast.import "Report"

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
  #
  # Although in the previous example we enabled the IPv4 forwarding using by
  # setting +forward_ipv4+ to true. However, under the hood, the kernel maps
  # boolean values to "1" or "0". If you want to access to that raw value,
  # you can prepend "raw_" to the method's name.
  #
  # @example Accessing the raw value of a setting
  #   sysctl = SysctlConfig.new
  #   sysctl.load
  #   sysctl.raw_forward_ipv6 #=> "0"
  #   sysctl.raw_forward_ipv6 = "1"
  class SysctlConfig
    include Yast::Logger
    include Yast::I18n
    extend Yast::I18n

    textdomain "base"

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
    # @param check_conflicts [Boolean] checking if the settings are overruled
    def save(check_conflicts: true)
      if check_conflicts
        conflict_files = conflict_files()
        if !conflict_files.empty?
          Yast::Report.Warning(format(_("The settings have been written to %{yast_file_name}.\n"\
            "But they will be overruled be manual setting described in %{file_list}."), yast_file_name: YAST_CONFIG_PATH, file_list: conflict_files.join(", ")))
        end
      end
      yast_config_file&.save
    end

    # Whether there is a conflict with given attributes
    #
    # @param only [Array<Symbol>] attributes to check
    # @return [Array<String>] list of conflicting files
    def conflict_files(only: [])
      return [] if yast_config_file.empty?

      conflicting_attrs = yast_config_file.present_attributes
      if !only.empty?
        # Dropping all not needed values
        conflicting_attrs.each_key do |key|
          conflicting_attrs.delete(key) unless only.include?(key)
        end
      end
      file_list = []
      higher_precedence_files.each do |file|
        # Checking all "higher" files if their values overrule the current
        # YAST settings.
        higher_attr = file.present_attributes
        file_list << file.file_path if conflicting_attrs.any? { |k, v| !higher_attr[k].nil? && v != higher_attr[k] }
      end
      file_list
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
      @higher_precedence_files ||= files[(yast_config_file_idx + 1)..-1]
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
        Yast::SCR.Read(Yast::Path.new(".target.dir"), path).map { |file| File.join(path, file) }
      else
        log.debug("Ignoring not valid path: #{path}")

        []
      end
    end

    def boot_config_path
      return @boot_config_path if @boot_config_path

      @boot_config_path = if !kernel_version.empty?
        "/boot/sysctl.conf-#{kernel_version}"
      else
        ""
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
