# Makefile.am for yast2/library/packages/src

yncludedir = $(yncludedir)/packages

YCPCFLAGS = -M ../../modules/ -M ../../wizard/src/ -I .

module_DATA =			\
	Require.ycp		\
	Package.ycp		\
	PackageAI.ycp		\
	PackageSystem.ycp	\
	PackageCallbacksInit.ycp

ynclude_DATA =			\
	common.ycp

symlinks:
	test -L packages || ln -sf . packages

ycpchook = symlinks

EXTRA_DIST = $(module_DATA) $(ynclude_DATA)

include $(top_srcdir)/Makefile.am.common
