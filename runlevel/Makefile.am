#
# Makefile.am for yast2-runlevel/src
#

myyncludedir = $(yncludedir)/runlevel

agent_SCRIPTS = ag_initscripts

scrconf_DATA = initscripts.scr insserv_conf.scr


myynclude_DATA =		\
	toposort.ycp

module_DATA = Runlevel.ycp

config_DATA = 

EXTRA_DIST = $(client_DATA) $(myynclude_DATA) $(config_DATA) $(agent_SCRIPTS) $(scrconf_DATA) $(module_DATA)

