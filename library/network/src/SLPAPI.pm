#
# SLPAPI.pm
# wrapper for SPL.ycp functions, included in yast2-slp package
#

package SLPAPI;

use strict;
use YaST::YCP qw(:LOGGING Boolean sformat);;
#use YaPI;
use Data::Dumper;

YaST::YCP::Import ("SLP");

our %TYPEINFO;

use strict;
#use Errno qw(ENOENT);


# Issue the query for services
# @param pcServiceType The Service Type String, including authority string if
# any, for the request, such as can be discovered using  SLPSrvTypes(). 
# This could be, for example "service:printer:lpr" or "service:nfs".
# @param pcScopeList comma separated  list of scope names to search for
# service types.
# @return list<map> List of Services
BEGIN{ $TYPEINFO{FindSrvs} = ["function", ["list", ["map", "string", "any"] ], "string", "string"];}
sub FindSrvs {

    my ($self, $pcServiceType, $pcScopeList)       = @_;
    return SLP->FindSrvs ($pcServiceType, $pcScopeList);
}

42
