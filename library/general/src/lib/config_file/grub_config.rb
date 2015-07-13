require "config_file/config_file"
require "config_file/keyvalue_parser"

module ConfigFile
  PARSER = Keyvalue_Parser
  PATH = "/etc/default/grub"

  class GrubConfig < ConfigFile
    def initialize(file_class: File)
      super(PARSER, PATH, file_class: file_class) 
    end

    def os_prober_enabled?
      return true unless data["GRUB_DISABLE_OS_PROBER"]
      return data["GRUB_DISABLE_OS_PROBER"][:value] != "true"
    end

    def disable_os_prober
      data["GRUB_DISABLE_OS_PROBER"] ||= {}
      data["GRUB_DISABLE_OS_PROBER"][:value] = "true"
      data["GRUB_DISABLE_OS_PROBER"][:commented_out] = false
    end

    def enable_os_prober
      data["GRUB_DISABLE_OS_PROBER"] ||= {}
      data["GRUB_DISABLE_OS_PROBER"][:value] = "false"
      data["GRUB_DISABLE_OS_PROBER"][:commented_out] = false
    end

    def disable_recovery_entry
      data["GRUB_DISABLE_RECOVERY"] ||= {}
      data["GRUB_DISABLE_RECOVERY"][:value] = "true"
      data["GRUB_DISABLE_RECOVERY"][:commented_out] = false
      data["GRUB_CMDLINE_LINUX_RECOVERY"] ||= {}
      data["GRUB_CMDLINE_LINUX_RECOVERY"][:commented_out] = true
    end

    def enable_recovery_entry(kernel_params)
      data["GRUB_DISABLE_RECOVERY"] ||= {}
      data["GRUB_DISABLE_RECOVERY"][:value] = "true"
      data["GRUB_DISABLE_RECOVERY"][:commented_out] = false
      data["GRUB_CMDLINE_LINUX_RECOVERY"] ||= {}
      data["GRUB_CMDLINE_LINUX_RECOVERY"][:value] = kernel_params
      data["GRUB_CMDLINE_LINUX_RECOVERY"][:commented_out] = false
    end
  end
end
