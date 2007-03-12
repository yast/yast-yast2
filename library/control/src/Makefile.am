#
# Makefile.am for control/src
#

productdir = ${sysconfdir}/YaST2

module_DATA =			\
	ProductControl.ycp	\
	ProductFeatures.ycp	\
	Hooks.ycp		\
	GetInstArgs.ycp		\
	Installation.ycp

EXTRA_DIST = $(module_DATA)

YCPCFLAGS = -M ../../modules -M ../../xml/src -M ../../wizard/src -M ../../types/src

include $(top_srcdir)/Makefile.am.common
