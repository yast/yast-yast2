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


# Return the map of services enabled in given runlevel
# Parameter is an argument map with possible keys:
# 	"runlevel" 	: integer
#	"read_status"	: if present, service status will be queried
# returns array of hashes
BEGIN{$TYPEINFO{Read} = ["function",
    ["list", [ "map", "string", "any"]],
    ["map", "string", "any"]];
}
sub Read {

  my $self	= shift;
  my $args	= shift;
  my @ret	= ();
  my $runlevel	= 5;
  $runlevel	= $args->{"runlevel"} if defined $args->{"runlevel"};

  foreach my $name (@{Service->EnabledServices ($runlevel)}) {
    my $s      = {
	"name"	=> $name
    };
    $s->{"status"}	= Service->Status ($name) if ($args->{"read_status"} || 0);
    push @ret, $s;
  }
  return \@ret;
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
