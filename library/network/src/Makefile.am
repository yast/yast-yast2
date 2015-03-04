# Sources for yast2

module_DATA = \
  modules/PortAliases.rb \
  modules/SuSEFirewall.rb \
  modules/NetworkConfig.rb \
  modules/Internet.rb \
  modules/SuSEFirewallProposal.rb \
  modules/PortRanges.rb \
  modules/NetworkInterfaces.rb \
  modules/CWMFirewallInterfaces.rb \
  modules/NetworkPopup.rb \
  modules/NetworkService.rb \
  modules/SuSEFirewallExpertRules.rb \
  modules/SuSEFirewallServices.rb \
  modules/SLPAPI.pm \
  modules/DnsServerAPI.pm

scrconf_DATA = \
  scrconf/sysconfig_SuSEfirewall2.scr \
  scrconf/net_showexports.scr \
  scrconf/network.scr

agent_SCRIPTS = \
  servers_non_y2/ag_showexports

ylibdir = @ylibdir@/network
ylib_DATA = \
  lib/network/firewalld.rb

EXTRA_DIST = $(module_DATA) $(scrconf_DATA) $(agent_SCRIPTS) $(ylib_DATA)

include $(top_srcdir)/Makefile.am.common