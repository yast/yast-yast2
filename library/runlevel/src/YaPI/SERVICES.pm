package YaPI::SERVICES;

use strict;
use YaST::YCP qw(:LOGGING);
use YaPI;
use YAML;
use Data::Dumper;

# ------------------- imported modules
YaST::YCP::Import ("Service");
YaST::YCP::Import ("SCR");
# -------------------------------------

our $VERSION            = '1.0.0';
our @CAPABILITIES       = ('SLES11');
our %TYPEINFO;

# path to file with list of services
my $service_list_file	= "/etc/YaST2/custom_services.yml";

# read the services from config file and return list of maps
sub get_services {

  if (! -r $service_list_file) {
    y2error ("file $service_list_file does not exists or is not readable");
    returna {};
  }

  my $services	= YAML::LoadFile ($service_list_file);

  if (!defined $services || ref ($services) ne "HASH") {
      y2error ("service list cannot be read");
      return {};
  }
  return $services;
}

# call the status script, argument is service hash
sub get_service_status {

    my $service	= shift;
    my $status	= -1;
    my $name	= $service->{"name"};

    if (defined $service->{"status"}) {
	# call the custom status script
        my $out	= SCR->Execute (".target.bash_output", $service->{"status"});
        if (!defined ($out->{"exit"})) {
	    y2error ("error calling status script: ", Dumper ($out));
	}
	else {
	    $status	= $out->{"exit"};
	}
    }
    else {
	# call the init script
	$status	= Service->Status ($name);
    }
    return $status;
}


BEGIN{$TYPEINFO{Read} = ["function",
    ["list", [ "map", "string", "any"]]];
}
sub Read {

  my $self	= shift;
  my @ret	= ();

  my $services	= get_services ();
  while (my ($name, $service) = each %$services) {

    y2milestone ("service: ", Dumper ($service));
    my $s	= {
	"name"		=> $name,
	"status"	=> get_service_status ($service)
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

  my $found	= 0;

  my $service	= {
    "name"	=> $name,
    "status"	=> -1 # not found
  };

  my $services	= get_services ();
  if (! defined ($services->{$name}) || ref ($services->{$name} ne "HASH")) {
      y2error ("service $name not found in the list");
      return $service;
  }
  $service->{"status"}	= get_service_status ($services->{$name});
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

  my $services	= get_services ();
  if (! defined ($services->{$name}) || ref ($services->{$name} ne "HASH")) {
      y2error ("service $name not found in the list");
      return $ret;
  }
  my $service	= $services->{$name};
  if (defined $service->{$action}) {
    $ret	= SCR->Execute (".target.bash_output", $service->{$action});
  }
  else {
    $ret        = Service->RunInitScriptOutput ($name, $action);
  }
  return $ret;
}
1;
