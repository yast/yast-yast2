# Makefile.am for yast2/library/modules

SUBDIRS = . testsuite

module_DATA = $(wildcard *.ycp) Version.ycp
EXTRA_DIST = $(module_DATA) Version.ycp.in

YCPCFLAGS = -M ../types/src

include $(top_srcdir)/Makefile.am.common
