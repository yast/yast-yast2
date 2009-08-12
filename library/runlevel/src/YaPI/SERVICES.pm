package YaPI::SERVICES;

use strict;
use YaST::YCP qw(Boolean);
use YaPI;

textdomain("runlevel");

# ------------------- imported modules
YaST::YCP::Import ("Service");
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

  # FIXME read the list of services from config file
  foreach my $name ("cron", "openvpn") {
    my $service	= {
	"name"		=> $name,
	"status"	=> Service->Status ($name)
    };
    push @ret, $service;
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
  my $ret	= {};

  # service with init script
  if (1) {
    $ret	= Service->RunInitScriptOutput ($name, $action);
  }
  # FIXME other services

  return $ret;
}
1;
