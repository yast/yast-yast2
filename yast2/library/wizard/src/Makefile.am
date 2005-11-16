#
# Makefile.am for yast2/library/wizard/src
#

htmldir = @docdir@/wizard
yncludedir = @yncludedir@/ui

module_DATA =			\
	Confirm.ycp		\
	NetworkPopup.ycp	\
	Wizard.ycp		\
	Wizard_hw.ycp		\
	Progress.ycp		\
	Report.ycp		\
	Summary.ycp		\
	HTML.ycp

EXTRA_DIST = $(module_DATA)

YCPCFLAGS = -M ../../modules -M ../../types/src

include $(top_srcdir)/Makefile.am.common
