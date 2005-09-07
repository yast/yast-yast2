#
# Makefile.am for control/src
#

productdir = ${sysconfdir}/YaST2

module_DATA =			\
	ProductControl.ycp	\
	ProductFeatures.ycp	\
	Hooks.ycp

fillup_DATA = YaST2.ProductFeatures

EXTRA_DIST = $(module_DATA) $(fillup_DATA)

YCPCFLAGS = -M ../../modules -M ../../xml/src -M ../../wizard/src

include $(top_srcdir)/Makefile.am.common
