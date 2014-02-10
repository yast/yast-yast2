# Sources for yast2

module_DATA = \
  modules/Hotplug.rb \
  modules/Initrd.rb \
  modules/ModuleLoading.rb \
  modules/FileChanges.rb \
  modules/ModulesConf.rb \
  modules/Kernel.rb \
  modules/HWConfig.rb \
  modules/HwStatus.rb

client_DATA = \
  clients/view_anymsg.rb

yncludedir = @yncludedir@/hwinfo
ynclude_DATA = \
  include/hwinfo/classnames.rb

scrconf_DATA = \
  scrconf/cfg_hardware.scr \
  scrconf/proc_cpuinfo.scr \
  scrconf/boot_vmlinuz_version.scr \
  scrconf/cfg_kernel.scr \
  scrconf/proc_cmdline.scr

desktop_DATA = \
  desktop/messages.desktop

ylibdir = @ylibdir@/yast2
ylib_DATA = \
  lib/yast2/hw_detection.rb


EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(desktop_DATA) $(ylib_DATA)

include $(top_srcdir)/Makefile.am.common
