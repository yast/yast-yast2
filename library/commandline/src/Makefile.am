#
# Makefile.am for yast2/library/commandline/src/
#

yncludedir = @yncludedir@/commandline

client_DATA =

ynclude_DATA = commandline.ycp

module_DATA =			\
	CommandLine.ycp

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA)

YCPCFLAGS = -M ../../types/src -M ../../modules -M ../../wizard/src

include $(top_srcdir)/Makefile.am.common
