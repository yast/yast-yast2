# Makefile.am for yast2/library/runlevel/src

agent_SCRIPTS = ag_initscripts

scrconf_DATA = initscripts.scr

module_DATA = Service.ycp Runlevel.ycp

YaPI_perldir = @moduledir@/YaPI

YaPI_perl_DATA = \
    YaPI/SERVICES.pm

EXTRA_DIST = $(agent_SCRIPTS)	\
	$(scrconf_DATA) $(module_DATA) $(YaPI_perl_DATA)

include $(top_srcdir)/Makefile.am.common
