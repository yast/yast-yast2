# Makefile.am for yast2/library/packages/src

YCPCFLAGS = -M ../../modules/ -M ../../wizard/src/

module_DATA =			\
	Require.ycp		\
	PackageCallbacksInit.ycp	
#	Package.ycp		\
#	PackageAI.ycp		\
#	PackageSystem.ycp

#ynclude_DATA =			\
#	common.ycp

EXTRA_DIST = $(module_DATA) 

#$(ynclude_DATA)

include $(top_srcdir)/Makefile.am.common
