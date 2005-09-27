# Makefile.am for yast2/library/modules

module_DATA = $(wildcard *.ycp)
EXTRA_DIST = $(module_DATA)

YCPCFLAGS = -M ../../wizard/src -M ../../modules -M ../../types/src -M ../../types/src

include $(top_srcdir)/Makefile.am.common
