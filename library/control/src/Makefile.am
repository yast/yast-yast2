#
# Makefile.am for control/src
#

productdir = ${sysconfdir}/YaST2

module_DATA =			\
	ProductControl.ycp	\
	Hooks.ycp

product_DATA = ProductFeatures

EXTRA_DIST = $(module_DATA) $(product_DATA)

YCPCFLAGS = -M ../../modules -M ../../xml/src -M ../../wizard/src

include $(top_srcdir)/Makefile.am.common
