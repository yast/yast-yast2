# Makefile.am for yast2/library/wizard/src

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

ynclude_DATA =			\
	file_popups.ycp

EXTRA_DIST = $(ynclude_DATA) $(module_DATA)

YCPCFLAGS = -M ../../modules

include $(top_srcdir)/Makefile.am.common
