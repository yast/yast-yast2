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

# runlevel: Service, wizard: Report, Progress
YCPCFLAGS = -M ../../types/src -M ../../modules -M ../../runlevel/src -M ../../wizard/src -M ../../cwm/src
include $(top_srcdir)/Makefile.am.common
