package YaPI::SERVICES;

use strict;
use YaST::YCP qw(:LOGGING);
use YaPI;
use Data::Dumper;

# ------------------- imported modules
YaST::YCP::Import ("Directory");
YaST::YCP::Import ("FileUtils");
YaST::YCP::Import ("Package");
YaST::YCP::Import ("Service");
YaST::YCP::Import ("SCR");
# -------------------------------------

our $VERSION            = '1.0.0';
our @CAPABILITIES       = ('SLES11');
our %TYPEINFO;

my $custom_services_file	= "/tmp/custom_services.yml";

my $error_message		= "";

# log error message and fill it into $error_message variable
sub report_error {
  $error_message	= shift;
  y2error ($error_message);
}

# parse the file with custom services and return the hash describing the file
sub parse_custom_services {

  if (!FileUtils->Exists ($custom_services_file)) {
    report_error ("$custom_services_file file not present");
    return {};
  }

  if (!Package->Installed ("yast2-ruby-bindings")) {
    report_error ("yast2-ruby-bindings not installed, cannot read custom services");
    return {};
  }

  if (!FileUtils->Exists (Directory->moduledir()."/YML.rb")) {
    report_error ("YML.rb not present, cannot parse config file");
    return {};
  }
  
  YaST::YCP::Import ("YML");

  my $parsed = YML->parse ($custom_services_file);

  if (!defined $parsed || ref ($parsed) ne "HASH") {
    report_error ("custom services file could not be read");
    return {};
  }
  return $parsed;
}

# read the list of custom services and return the information about them
# if requested, read the status of services
sub read_custom_services {

  my $args	= shift;
  my @ret	= ();
  my $services	= parse_custom_services ();
  foreach my $name (keys %$services) {
    my $s      = {
	"name"		=> $name,
	"description"	=> $services->{$name}{"description"} || ""
    };
    if ($args->{"read_status"} || 0)
    {
	my $cmd	= $services->{$name}{"status"};
	if (!$cmd) {
	    report_error ("status script for $name not defined or empty");
	    next;
	}
	my $out     = SCR->Execute (".target.bash_output", $cmd);
	$s->{"status"}	= $out->{"exit"};
    }
    push @ret, $s;
  }
  return \@ret;
}

# read infomation about custom service and execute given command with it
sub execute_custom_script {

  my $name	= shift;
  my $action	= shift;
  my $services	= parse_custom_services ();
  my $ret	= {
      "stdout"	=> "",
      "stderr"	=> "failure",
      "exit"	=> 255
  };

  if (%$services) {
    my $service	= $services->{$name};
    if (!defined $service || ref ($service) ne "HASH" || ! %$service) {
	report_error ("service $name not defined or empty in config file");
	$ret->{"stderr"}	= $error_message;
	return $ret;
    }
    my $cmd	= $services->{$name}{$action};
    if (!$cmd) {
	report_error ("'$action' script for $name not defined or empty");
	$ret->{"stderr"}	= $error_message;
	return $ret;
    }
    $ret	= SCR->Execute (".target.bash_output", $cmd);
  }
  return $ret;
}

# Return the map of services enabled in given runlevel
# Parameter is an argument map with possible keys:
# 	"runlevel" 	: integer
#	"read_status"	: if present, service status will be queried
#	"custom"	: if present, custom services (defined in config file) will be read
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

  if ($args->{"custom"} || 0) {
    return read_custom_services ($args);
  }

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
    [ "map", "string", "any"]];
}
sub Execute {

  my $self	= shift;

  my $args	= shift;
  my $name	= $args->{"name"} || "";
  my $action	= $args->{"action"} || "";

  if ($args->{"custom"} || 0) {
    return execute_custom_script ($name, $action);
  }
  else {
    return Service->RunInitScriptOutput ($name, $action);
  }
}
1;
