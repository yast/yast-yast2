# Copyright (c) [2019] SUSE LLC
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

module CFA
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

    YAST_CONFIG_PATH = "/etc/sysctl.d/30-yast.conf".freeze
    private_constant :YAST_CONFIG_PATH

    class << self
      def define_attr(attr)
        define_method attr do
          file = files.reverse.find { |f| f.present?(attr) }
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

    def save
      yast_config_file&.save
    end

    # Whether there is a conflict with given attributes
    #
    # @param only [Array<String,Symbol>] attributes to check
    # @return [Boolean] true if any conflict is found; false otherwise
    def conflict?(only: [])
      return false if yast_config_file.empty?

      conflicting_attrs = yast_config_file.present_attributes & only

      higher_precedence_files.any? do |file|
        !(file.present_attributes & conflicting_attrs).empty?
      end
    end

    def files
      @files ||= config_paths.map { |file| Sysctl.new(file_path: file) }
    end

  private

    def yast_config_file
      @yast_config_file ||= files.find { |f| f.file_path == YAST_CONFIG_PATH }
    end

    def lower_precedence_files
      @lower_precedence_files ||= files[1...yast_config_file_idx]
    end

    def higher_precedence_files
      @higher_precedence_files ||= files[yast_config_file_idx + 1..]
    end

    def config_paths
      paths = PATHS.each_with_object([YAST_CONFIG_PATH]) do |path, all|
        all.concat(file_paths_in(path))
      end

      paths.uniq! { |f| File.basename(f) }
      # Sort files lexicographic
      paths.sort_by! { |f| File.basename(f) }

      # Prepend the kernel configuration file
      paths.unshift(boot_config_path)

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
      @boot_config_path ||= "/boot/sysctl.conf-#{kernel_version}"
    end

    def boot_config_file
      @boot_config_file ||= files.find { |f| f.file_path == boot_config_path }
    end

    # FIXME: Move to a better place (?)
    def kernel_version
      # TODO: on_target
      @kernel_version ||= Yast::Execute.locally.stdout("/usr/bin/uname", "-r").to_s.chomp
    end

    def yast_config_file_idx
      @yast_config_file_idx ||= files.find_index { |f| f == yast_config_file }
    end

    def yast_defined_attrs(attrs)
      # FIXME: what about having a Sysctl#defined_attrs ?
      defined_attrs = Sysctl.known_attributes.select { |a| yast_config_file.present?(a) }
      attrs.map(&:to_sym) & defined_attrs
    end
  end
end
