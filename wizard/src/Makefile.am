#
# Makefile.am for yast2/wizard/src
#

htmldir = @docdir@/wizard
yncludedir = @yncludedir@/ui

module_DATA =			\
	Popup.ycp		\
	Wizard.ycp		\
	Wizard_hw.ycp		\
	Progress.ycp		\
	Report.ycp		\
	Summary.ycp		\
	HTML.ycp

ynclude_DATA =			\
	common_popups.ycp	\
	file_popups.ycp		\
	common_messages.ycp	\
	common_functions.ycp	\
	summary.ycp

html_DATA = README.popups

EXTRA_DIST = $(ynclude_DATA) $(module_DATA) $(html_DATA)
