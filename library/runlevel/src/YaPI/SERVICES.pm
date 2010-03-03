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

my $custom_services_file	= "/etc/webyast/custom_services.yml";

my $error_message		= "";

# check for key presence in given list
sub contains {
    my ( $list, $key, $ignorecase ) = @_;
    if ( $ignorecase ) {
        if ( grep /^$key$/i, @{$list} ) {
            return 1;
        }
    } else {
        if ( grep /^$key$/, @{$list} ) {
            return 1;
        }
    }
    return 0;
}

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
	"name"		=> $name
    };
    $s->{"description"}	= ($services->{$name}{"description"} || "") if $args->{"description"} || 0;
    $s->{"shortdescription"}= ($services->{$name}{"shortdescription"} || "") if $args->{"shortdescription"} || 0;

    # read list of available commands, it may be limited for 'custom service'
    my @commands	= ();
    foreach my $key (keys %{$services->{$name}}) {
	if (contains (["start","stop","restart","reload","try-restart"], $key, 1)) {
	    push @commands, $key;
	}
    }
    $s->{"commands"}	= \@commands;

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

# Return the list of services enabled in given runlevel, or even all available.
#
# Parameter is an argument map with possible keys:
#	"service"	: if defined, only the status of _this given service_ will be returned (= list with one item)
# 	"runlevel" 	: integer; if not defined, current runlevel will be used
#	"read_status"	: if true, service status will be queried and returned for each service
#	"custom"	: if true, custom services (defined in config file) will be read (otherwise list of init.d services)
#	"description"	: if true, read the description of each service
#	"only_enabled"	: if true, return only list of services enabled in given runlevel
#		- neither "start_runlevels", nor "enabled" key will be part of resulting maps
#	"start_runlevels" if true, each service's result map will contain list of runlevels where it is started
#		- if not present (or false), "enabled" key with boolean value will be returned instead
#	"filter"	: list of strings; defines filtered list of services that should be returned
# @returns array of hashes
BEGIN{$TYPEINFO{Read} = ["function",
    ["list", [ "map", "string", "any"]],
    ["map", "string", "any"]];
}
sub Read {

  my $self	= shift;
  my $args	= shift;
  my @ret	= ();
  my $runlevel	= SCR->Read (".init.scripts.current_runlevel");
  $runlevel	= $args->{"runlevel"} if defined $args->{"runlevel"};

  my @filter	= ();
  @filter	= @{$args->{"filter"}} if defined $args->{"filter"};
  my $filter_map= {};
  foreach my $s (@filter) {
      $filter_map->{$s}	= 1;
  }

  # only read status of one service if the name was given
  if ($args->{"service"} || "") {
    my $exec	= $self->Execute ({
	"name" 		=> $args->{"service"} || "",
	"action"	=> "status",
	"custom"	=> $args->{"custom"} || 0
    });
    my $s	= {
	"name"  	=> $args->{"service"} || "",
	"status"	=> $exec->{"exit"} || 0
    };
    push @ret, $s;
    return \@ret;
  }

  # read only custom services
  if ($args->{"custom"} || 0) {
    return read_custom_services ($args);
  }

  if ($args->{"only_enabled"}) {
    # generate the output list
    foreach my $name (@{Service->EnabledServices ($runlevel)}) {
	next if (@filter && !defined $filter_map->{$name}); # should not be returned
	my $s      = {
	    "name"		=> $name,
	};
	$s->{"status"}	= Service->Status ($name) if ($args->{"read_status"} || 0);
	if (($args->{"description"} || 0) || ($args->{"shortdescription"} || 0)) {
	    my $info	= Service->Info ($name);
	    $s->{"description"}	= ($info->{"description"} || "") if $args->{"description"} || 0;
	    $s->{"shortdescription"}= ($info->{"shortdescription"} || "") if $args->{"shortdescription"} || 0;
	}
	push @ret, $s;
    }
  }
  else {
    my $details = SCR->Read (".init.scripts.runlevels");
    
    # copied from RunlevelEd::Read
    my $full_services	= SCR->Read (".init.scripts.comments");
    while (my ($name, $info) = each %$full_services) {

	next if (@filter && !defined $filter_map->{$name}); # should not be returned

	my $second_service = $details->{$name} || {};

	my $s      = {
	    "name"		=> $name
	};
	next if (contains ($info->{"defstart"} || [], "B", 1));

	if ($args->{"start_runlevels"} || 0) {
	    $s->{"start_runlevels"}	= $second_service->{"start"} || [];
	}
	else {
	    my $start		= $second_service->{"start"} || [];
	    # for "B" check, see RunlevelEd::StartContainsImplicitly
	    $s->{"enabled"}	= YaST::YCP::Boolean (contains ($start, $runlevel, 1) || contains ($start, "B", 1));
	}
	$s->{"status"}		= Service->Status ($name) if ($args->{"read_status"} || 0);
	$s->{"description"}	= ($info->{"description"} || "") if $args->{"description"} || 0;
	$s->{"shortdescription"}= ($info->{"shortdescription"} || "") if $args->{"shortdescription"} || 0;
	push @ret, $s;
    }
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
# If the action is start or stop, it will also enable (resp. disable)
# the service for current runlevel.
#
# parameter is a map where "name" is service name, "action" means what to do
# - if "only_execute" key is present, do not continue with enabling/disabling
# - if action is "enable" or "disable", only enables/disables service
# - if "custom" key is present (with true value), indicates custom service, which
# has special handling. Also, custom service will not be enabled/disabled.
#
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

  return self->Enable ($args) if ($action eq "enable" || $action eq "disable");

  if ($args->{"custom"} || 0) {
    return execute_custom_script ($name, $action);
  }
  else {
    my $ret = Service->RunInitScriptOutput ($name, $action);
    if (($action eq "start" || $action eq "stop") && !($args->{"only_execute"} || 0)) {
	if (($ret->{"exit"} || 0) ne 0) {
	    y2error ("action '$action' failed");
	    return $ret;
	}
	if ($action eq "start") {
	    $args->{"action"}	= "enable";
	}
	else {
	    $args->{"action"}	= "disable";
	}
	return $self->Enable ($args);
    }
    return $ret;
  }
}

# Enable/Disable given service in current runlevel
# parameter is a map where "name" is service name, "action" means what to do
# return value is map with "exit", "stdout" and "stderr" keys
BEGIN{$TYPEINFO{Enable} = ["function",
    [ "map", "string", "any"],
    [ "map", "string", "any"]];
}
sub Enable {

  my $self	= shift;
  my $args	= shift;
  my $name	= $args->{"name"} || "";
  my $action	= $args->{"action"} || "";
  my $ret	= {
      "stdout"	=> "",
      "stderr"	=> "",
      "exit"	=> 0
  };
  if ($action eq "enable") {
    unless (Service->Enable ($name)) {
	$ret->{"stderr"}	= "Failed to enable service $name.";
	$ret->{"exit"}		= 1000;
    }
  }
  elsif ($action eq "disable") {
    unless (Service->Disable ($name)) {
	$ret->{"stderr"}	= "Failed to disable service $name.";
	$ret->{"exit"}		= 2000;
    }
  }
  else {
    $ret->{"stderr"}	= "Unknown action '$action'";
    $ret->{"exit"}		= 3;
  }
  return  $ret;
}

1;
