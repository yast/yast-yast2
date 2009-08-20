package YaPI::SERVICES;

use strict;
use YaST::YCP qw(:LOGGING);
use YaPI;
use Data::Dumper;

# ------------------- imported modules
YaST::YCP::Import ("Service");
YaST::YCP::Import ("SCR");
# -------------------------------------

our $VERSION            = '1.0.0';
our @CAPABILITIES       = ('SLES11');
our %TYPEINFO;


# Return the list of services enabled in given runlevel
BEGIN{$TYPEINFO{Read} = ["function",
    ["list", "string"], "integer"];
}
sub Read {

  my $self	= shift;
  my $runlevel	= shift;

  return Service->EnabledServices ($runlevel);
}

# Return the status of given service 
# return value is the exit code of status function
BEGIN{$TYPEINFO{Get} = ["function",
    "integer", "string" ];
}
sub Get {

  my $self	= shift;
  my $name	= shift;

  return Service->Status ($name);
}

# Executes an action (e.g. "restart") with given service
# return value is map with "exit", "stdout" and "stderr" keys
BEGIN{$TYPEINFO{Execute} = ["function",
    [ "map", "string", "any"],
    "string", "string" ];
}
sub Execute {

  my $self	= shift;
  my $name	= shift;
  my $action	= shift;
  return Service->RunInitScriptOutput ($name, $action);
}
1;
