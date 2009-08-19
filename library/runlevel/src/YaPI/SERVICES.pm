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


BEGIN{$TYPEINFO{Read} = ["function",
    ["list", [ "map", "string", "any"]]];
}
sub Read {

  my $self	= shift;
  my @ret	= ();

  my $current_runlevel	= 3; #FIXME which runlevel?

  my $services	= Service->EnabledServices ($current_runlevel);
  foreach my $name (@$services) {
    my $s	= {
	"name"		=> $name
#read the status on demand, this is costly
#	"status"	=> Service->Status ($name)
    };
    push @ret, $s;
  }
  return \@ret;
}

BEGIN{$TYPEINFO{Get} = ["function",
    [ "map", "string", "any"],
    "string" ];
}
sub Get {

  my $self	= shift;
  my $name	= shift;

  my $service	= {
    "name"	=> $name,
    "status"	=> Service->Status ($name)
  };
  return $service;
}

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
