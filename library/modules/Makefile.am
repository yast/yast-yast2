# Makefile.am for yast2/library/modules

SUBDIRS = . testsuite

module_DATA = $(wildcard *.ycp) Version.ycp
EXTRA_DIST = $(module_DATA) Version.ycp.in

YCPCFLAGS = -M ../types/src

# people are lazy to run Makefile.cvs so let's substitute it
# also here in addition to configure (#40492)
Version.ycp: Version.ycp.in ${top_srcdir}/VERSION
	sed -e "s/\@VERSION\@/`cat ${top_srcdir}/VERSION`/g" $< > $@

include $(top_srcdir)/Makefile.am.common
