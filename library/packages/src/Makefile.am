# Makefile.am for yast2/library/packages/src

yncludedir = @yncludedir@/packages

YCPCFLAGS = -M ../../modules/ -M ../../wizard/src -M ../../system/src/ -M ../../types/src -M ../../commandline/src -M ../../xml/src -M ../../control/src

module_DATA = $(wildcard [A-Z]*.ycp [A-Z]*.pm)

ynclude_DATA =			\
	common.ycp

packages:
	ln -sf . packages

ycpchook = packages

EXTRA_DIST = $(module_DATA) $(ynclude_DATA)

include $(top_srcdir)/Makefile.am.common
