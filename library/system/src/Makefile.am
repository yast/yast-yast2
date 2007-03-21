# Makefile.am for yast2/library/modules

module_DATA = HWConfig.ycp Initrd.ycp Kernel.ycp ModuleLoading.ycp ModulesConf.ycp

yncludedir = @yncludedir@/hwinfo
ynclude_DATA = classnames.ycp

EXTRA_DIST = $(module_DATA) $(ynclude_DATA)

YCPCFLAGS = -M ../../wizard/src -M ../../modules -M ../../types/src -M ../../types/src

include $(top_srcdir)/Makefile.am.common
