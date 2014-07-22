# Sources for yast2

module_DATA = \
  modules/Service.rb \
  modules/Systemd.rb \
  modules/ServicesProposal.rb

scrconf_DATA = \
  scrconf/initscripts.scr

agent_SCRIPTS = \
  servers_non_y2/ag_initscripts

EXTRA_DIST = $(module_DATA) $(scrconf_DATA) $(agent_SCRIPTS)

include $(top_srcdir)/Makefile.am.common
