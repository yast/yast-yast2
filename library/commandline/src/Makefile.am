#
# Makefile.am for yast2/library/commandline/src/
#

module_DATA =			\
	CommandLine.ycp

client_DATA = \
        other_tools_warning.ycp

EXTRA_DIST = $(module_DATA) $(client_DATA)

YCPCFLAGS = -M ../../types/src -M ../../modules -M ../../wizard/src -M ../../xml/src

include $(top_srcdir)/Makefile.am.common
