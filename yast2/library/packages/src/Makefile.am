# Makefile.am for yast2/library/packages/src

yncludedir = @yncludedir@/packages

YCPCFLAGS = -M ../../modules/ -M ../../wizard/src/ -M ../../system/src/

module_DATA =			\
	Require.ycp		\
	Package.ycp		\
	PackageAI.ycp		\
	PackageSystem.ycp	\
	PackageCallbacksInit.ycp

ynclude_DATA =			\
	common.ycp

packages:
	ln -sf . packages

ycpchook = packages

EXTRA_DIST = $(module_DATA) $(ynclude_DATA)

include $(top_srcdir)/Makefile.am.common
