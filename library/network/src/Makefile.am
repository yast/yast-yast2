#
# Makefile.am for yast2/library/network/src/
#

client_DATA =

ynclude_DATA =

module_DATA =			\
	NetworkDevices.ycp	\
	SuSEFirewall.ycp	\
	SuSEFirewallServices.ycp	\
	PortAliases.ycp		\
	SuSEFirewallProposal.ycp	\
	CWMFirewallInterfaces.ycp

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA)

YCPCFLAGS = -M ../../types/src -M ../../modules
include $(top_srcdir)/Makefile.am.common
