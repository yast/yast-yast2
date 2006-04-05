#
# Makefile.am for yast2/library/network/src/
#

client_DATA =

ynclude_DATA =

module_DATA =			\
	NetworkConfig.ycp	\
	NetworkDevices.ycp	\
	NetworkService.ycp	\
	SuSEFirewall.ycp	\
	SuSEFirewallServices.ycp	\
	PortAliases.ycp		\
	SuSEFirewallProposal.ycp	\
	CWMFirewallInterfaces.ycp

EXTRA_DIST = $(client_DATA) $(ynclude_DATA) $(module_DATA)

# runlevel: Service, wizard: Report, Progress
YCPCFLAGS = -M ../../types/src -M ../../modules -M ../../runlevel/src -M ../../wizard/src -M ../../cwm/src -M ../../control/src -M ../../xml/src -M ../../commandline/src -M ../../packages/src
include $(top_srcdir)/Makefile.am.common
