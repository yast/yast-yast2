# Makefile.am for yast2/library/runlevel/src

agent_SCRIPTS = ag_initscripts

scrconf_DATA = initscripts.scr

module_DATA = Service.ycp Runlevel.ycp Systemd.ycp

EXTRA_DIST = $(agent_SCRIPTS)	\
	$(scrconf_DATA) $(module_DATA)

YCPCFLAGS = -M ../../types/src -M ../../modules
include $(top_srcdir)/Makefile.am.common
