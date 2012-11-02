# Makefile.am for yast2/library/modules

module_DATA = $(wildcard [A-Z]*.ycp)

yncludedir = @yncludedir@/hwinfo
ynclude_DATA = classnames.ycp

client_DATA = view_anymsg.ycp

desktop_DATA = messages.desktop

EXTRA_DIST = $(module_DATA) $(ynclude_DATA) $(client_DATA) $(desktop_DATA)

YCPCFLAGS = -M ../../wizard/src -M ../../modules -M ../../types/src -M ../../types/src

include $(top_srcdir)/Makefile.am.common
