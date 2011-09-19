#
# Makefile.am for yast2/library/wizard/src
#

htmldir = @docdir@/wizard
yncludedir = @yncludedir@/ui

module_DATA =			\
	Confirm.ycp		\
	Wizard.ycp		\
	Progress.ycp		\
	HTML.ycp

EXTRA_DIST = $(module_DATA)

YCPCFLAGS = -M ../../modules -M ../../types/src -M ../../xml/src -M ../../commandline/src -M ../../network/src/ -M ../../runlevel/src -M ../../desktop/src

include $(top_srcdir)/Makefile.am.common
