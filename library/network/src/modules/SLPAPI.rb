require "yast"

module Yast
  # wrapper for SLP.ycp functions, included in yast2-slp package
  # TODO: useless class, why not use SLP directly?

  class SLPAPIClass < Module
    # Issue the query for services
    # @param pcServiceType The Service Type String, including authority string if
    # any, for the request, such as can be discovered using  SLPSrvTypes().
    # This could be, for example "service:printer:lpr" or "service:nfs".
    # @param pcScopeList comma separated  list of scope names to search for
    # service types.
    # @return list<map> List of Services
    def FindSrvs(pcServiceType, pcScopeList)
      Yast.import "SLP"
      SLP.FindSrvs(pcServiceType, pcScopeList)
    end

    publish :function => :FindSrvs, :type => "list <map> (string, string)"
  end

  SLPAPI = SLPAPIClass.new
end
