##
# File:		DnsServerAPI.pm
# Package:	Configuration of dns-server
# Summary:	Global functions for dns-server configurations.
# Authors:	Lukas Ocilka <locilka@suse.cz>
#
# Functions for dns-server configuration divided by logic sections
# of the configuration file.
##

###                                                                     ###
#                                                                         #
# Note: this version is under development. It is a functional extension   #
# for the previous non-functional version. It is not backward-compatible. #
#                                                                         #
###                                                                     ###

=head1 NAME

DnsServerAPI - DNS server configuration functional API

=head1 PREFACE

This package is the public functional YaST2 API to configure the Bind version 9

=head1 SYNOPSIS

in Perl
    use DnsServerAPI;
    my $categories = DnsServerAPI->GetLoggingCategories();

in YCP
    imoprt "DnsServerAPI";
    list <string> categories = DnsServerAPI::GetLoggingCategories();

Note: All arrays or hashes returned or accepted by this module are references
to them. However it is impossible to change the data through the references,
because the references are, actually, references to copies of the data.

=head1 DESCRIPTION

=over 2

=cut

### Real code starts here ->
package DnsServerAPI;

use strict;
use YaPI;
textdomain("dns-server");

use YaST::YCP qw( sformat y2milestone y2error y2warning );
YaST::YCP::Import ("DnsServer");
YaST::YCP::Import ("PackageSystem");
YaST::YCP::Import ("Service");
YaST::YCP::Import ("Progress");
# for reporting errors
YaST::YCP::Import ("Report");
# for syntax checking
YaST::YCP::Import ("IP");
# for syntax checking
YaST::YCP::Import ("Hostname");

our %TYPEINFO;
my $package_installed = -1;

my $SETTINGS = {
    'logging_channel_file' => 'log_file',
    'logging_channel_syslog' => 'log_syslog',
};

# FIXME: makes sense for SLES
my $OPTIONS = {
    'version' => {
	'type' => 'quoted-string',
	'record' => 'single',
    },
};

# LOCAL FUNCTIONS >>>

# Function returns list of strings created from BIND option '{ ... }';
# '{ a; b; c; }' -> ['a', 'b', 'c']
sub GetListFromRecord {
    my $record = shift || '';
    $record =~ s/(^[\t ]*\{[\t ]*|[\t ]*\}[\t ]*$)//g;
    $record =~ s/( +|;$)//g;

    return split(';', $record);
}

# Function returns BIND record created from list of strings
# ['a', 'b', 'c'] -> '{ a; b; c; }'
sub GetRecordFromList {
    my @records = @_;

    if (scalar(@records)>0) {
	return '{ '.join('; ', @records).'; }';
    } else {
	return '{ }';
    }
}

# Function returns sorted set of list
# ['a','c','a','b'] -> ['a','b','c']
sub ToSet {
    my @list = @_;
    my $map  = {};
    foreach (@list) {
	$map->{$_} = $_;
    }
    @list = ();
    foreach (sort {$a cmp $b} (keys(%{$map}))) {
	push @list, $_;
    }
    return @list;
}

# Function checks if the 1st parameter is a valid IPv4
# If not, opens error popup and returns false
sub CheckIPv4 {
    my $class = shift;
    my $ipv4  = shift || '';

    if (!IP->Check4($ipv4)) {
	# TRANSLATORS: Popup error message during parameters validation,
	#   %1 is a string that should be IPv4
	Report->Error(sformat(__("%1 is not a valid IPv4 address."), $ipv4)."\n\n".IP->Valid4());
	return 0;
    }
    
    return 1;
}

sub CheckZone {
    my $class = shift;
    my $zone  = shift || '';

    if (!$zone) {
	# TRANSLATORS: Popup error message, Calling function which needs DNS zone name defined
	Report->Error(__("The zone name must be defined."));
	return 0;
    }

    my $zones = $class->GetZones();
    foreach my $known_zone (keys %{$zones}) {
	return 1 if ($zone eq $known_zone);
    }
    
    # TRANSLATORS: Popup error message, Trying to get information from zone which doesn't exist,
    #   %1 is the zone name
    Report->Error(sformat(__("DNS zone %1 does not exist."), $zone));
    return 0;
}

sub CheckIPv4s {
    my $class = shift;
    my $ips   = shift || [];

    foreach my $ip (@{$ips}) {
	if (!$class->CheckIPv4($ip)) {
	    return 0;
	}
    }
    
    return 1;
}

sub ZoneIsMaster {
    my $class = shift;
    my $zone  = shift || '';

    if (!$zone) {
	y2error("Zone must be defined");
	return 0;
    }

    my $zones = $class->GetZones();
    foreach my $known_zone (keys %{$zones}) {
	return 1 if ($zone eq $known_zone && $zones->{$known_zone}->{'type'} eq 'master');
    }

    # TRANSLATORS: Popup error message, Trying manage records in zone which is not 'master' type
    #   only 'master' zone records can be managed
    #   %1 is the zone name
    Report->Error(sformat(__("DNS zone %1 is not type master."), $zone));
    return 0;
}

sub CheckZoneType {
    my $class = shift;
    my $type  = shift || '';

    if (!$type) {
	# TRANSLATORS: Popup error message, Calling function which needs DNS zone type defined
	Report->Error(__("The zone type must be defined."));
	return 0;
    }

    if ($type !~ /^(master|slave|forward)$/) {
	# TRANSLATORS: Popup error message, Calling function with unsupported DNZ zone type,
	#   %1 is the zone type
	Report->Error(sformat(__("Zone type %1 is not supported."), $type));
	return 0;
    }

    return 1;
}

sub CheckTransportACL {
    my $class = shift;
    my $acl   = shift || '';

    if (!$acl) {
	# TRANSLATORS: Popup error message, Calling function which needs ACL name defined
	Report->Error(__("The ACL name must be defined."));
	return 0;
    }

    my $acls = $class->GetACLs();
    foreach my $known_acl (keys %{$acls}) {
	return 1 if ($acl eq $known_acl);
    }

    # TRANSLATORS:  Popup error message, Calling function with unknown ACL,
    #   %1 is the ACL's name
    Report->Error(sformat(__("An ACL named %1 does not exist."), $acl));
    return 0;
}

sub CheckHostname {
    my $class = shift;
    my $hostname = shift || '';

    if (!$hostname) {
	# TRANSLATORS:  Popup error message, Calling function with undefined parameter
	Report->Error(__("The hostname must be defined."));
	return 0;
    }

    # FQDN
    if ($hostname =~ /\./) {
	# DNS FQDN must be finished with a dot
	if ($hostname =~ s/\.$//) {
	    if(Hostname->CheckFQ($hostname)) {
		return 1;
	    } else {
		# Popup error message, wrong FQDN format
		Report->Error(__("The hostname must be in the fully qualified domain name format."));
		return 0;
	    }
	# DNS FQDN which doesn't finish with a dot!
	} else {
	    # Popup error message, FQDN hostname must finish with a dot
	    Report->Error(__("The fully qualified hostname must end with a dot."));
	    return 0;
	}
    # Relative name
    } else {
	if (Hostname->Check($hostname)) {
	    return 1;
	} else {
	    # TRANSLATORS: Popup error message, wrong hostname, allowed syntax is described
	    #   two lines below using a pre-defined text
	    Report->Error(__("The hostname is invalid.")."\n\n".Hostname->ValidHost());
	    return 0;
	}
    }
}

sub CheckMXPriority {
    my $class = shift;
    my $prio  = shift || '';

    if (!$prio) {
	# TRANSLATORS: Popup error message, Checking parameters, MX priority is a needed parameter
	Report->Error(__("The mail exchange priority must be defined."));
	return 0;
    }

    if ($prio !~ /^[\d]+$/ || ($prio<0 && $prio>65535)) {
	# TRANSLATORS: Popup error message, Checking parameters, wrong format
	Report->Error(__("The mail exchange priority is invalid.
It must be a number from 0 to 65535.
"));
	return 0;
    }

    return 1;
}

sub CheckHostameInZone {
    my $class    = shift;
    my $hostname = shift || '';
    my $zone     = shift || '';

    # hostname is not relative
    if ($hostname =~ /\.$/) {
	# hostname does not end with the zone name (A, NS, MX ...)
	# hostname is not the same as the zone (domain NS, domain MX...)
	if ($hostname !~ /\.$zone\.$/ && $hostname !~ /^$zone\.$/) {
	    # TRANSLATORS: Popup error message, Wrong hostname which should be part of the zone,
	    #   %1 is the hostname, %2 is the zone name
	    Report->Error(sformat(__("The hostname %1 is not part of the zone %2.

The hostname must be relative to the zone or must end 
with the zone name followed by a dot, for example,
'dhcp1' or 'dhcp1.example.org.' for the zone 'dhcp.org'.
"), $hostname, $zone));
	    return 0;
	}
    }

    return 1;
}

sub CheckReverseIPv4 {
    my $class  = shift;
    my $reverseip = lc(shift) || '';

    # 1 integer
    if ($reverseip =~ /^(\d+)$/) {
	return 1 if ($1>=0 && $1<256);
    # 2 integers
    } elsif ($reverseip =~ /^(\d+)\.(\d+).(\d+)$/) {
	return 1 if ($1>=0 && $1<256 && $2>=0 && $2<256);
    # 3 integers
    } elsif ($reverseip =~ /^(\d+)\.(\d+).(\d+)$/) {
	return 1 if ($1>=0 && $1<256 && $2>=0 && $2<256 && $3>=0 && $3<256);
    # 4 integers
    } elsif ($reverseip =~ /^(\d+)\.(\d+).(\d+).(\d+)$/) {
	return 1 if ($1>=0 && $1<256 && $2>=0 && $2<256 && $3>=0 && $3<256 && $4>=0 && $4<256);
    # full format
    } elsif ($reverseip =~ /^(\d+)\.(\d+).(\d+).(\d+)\.in-addr\.arpa\.$/) {
	return 1 if ($1>=0 && $1<256 && $2>=0 && $2<256 && $3>=0 && $3<256 && $4>=0 && $4<256);
    }

    # TRANSLATORS: Popup error message, Wrong reverse IPv4,
    #   %1 is the reveresed IPv4
    Report->Error(sformat(__("The reverse IPv4 address %1 is invalid.

A valid reverse IPv4 consists of four integers in the range 0-255
separated by a dot then followed by the string '.in-addr.arpa.'.
For example, '1.32.168.192.in-addr.arpa.' for the IPv4 address '192.168.32.1'.
"), $reverseip));
    return 0;
}

sub CheckHostnameRelativity {
    my $class    = shift;
    my $hostname = shift || '';
    my $zone     = shift || '';

    # ending with a dot - it isn't relative
    if ($hostname =~ /\.$/) {
	return 1;
    }

    if ($zone =~ /\.in-addr\.arpa$/) {
	# TRANSLATORS: Popup error message, user can't use hostname %1 because it doesn't make
	#   sense to e relative to zone %2 (%2 is a reverse zone name like '32.200.192.in-addr.arpa')
	Report->Error(sformat(__("The relative hostname %1 cannot be used with zone %2.
Use a fully qualified hostname finished with a dot instead,
such as 'host.example.org.'.
"), $hostname, $zone));
	return 0;
    }

    return 1;
}

sub GetFullHostname {
    my $class    = shift;
    my $zone     = shift || '';
    my $hostname = shift || '';

    # record is realtive and is not IPv4
    if ($hostname !~ /\.$/ && !IP->Check4($hostname)) {
	$hostname .= '.'.$zone.'.';
    }

    return $hostname;
}

sub CheckResourceRecord {
    my $class  = shift;
    my $record = shift || {};

    foreach my $key ('type', 'key', 'value', 'zone') {
	$record->{$key} = '' if (not defined $record->{$key});
    }
    $record->{'type'} = uc($record->{'type'});

    if (!$record->{'type'}) {
	return 0;
    }

    if ($record->{'type'} eq 'A') {
	return 0 if (!$class->CheckHostname($record->{'key'}));
	return 0 if (!$class->CheckHostameInZone($record->{'key'},$record->{'zone'}));
	return 0 if (!$class->CheckIPv4($record->{'value'}));
	return 1;
    } elsif ($record->{'type'} eq 'CNAME') {
	return 0 if (!$class->CheckHostname($record->{'key'}));
	return 0 if (!$class->CheckHostameInZone($record->{'key'},$record->{'zone'}));
	return 0 if (!$class->CheckHostname($record->{'value'}));
	return 1;
    # FIXME: IPv6
    } elsif ($record->{'type'} eq 'PTR') {
	return 0 if (!$class->CheckReverseIPv4($record->{'key'}));
	return 0 if (!$class->CheckHostameInZone($record->{'key'},$record->{'zone'}));
	return 0 if (!$class->CheckHostname($record->{'value'}));
	return 1;
    } elsif ($record->{'type'} eq 'NS') {
	return 0 if (!$class->CheckHostname($record->{'key'}));
	return 0 if (!$class->CheckHostameInZone($record->{'key'},$record->{'zone'}));
	return 0 if (!$class->CheckHostnameRelativity($record->{'value'},$record->{'zone'}));
	return 0 if (!$class->CheckHostname($record->{'value'}));
	return 1;
    } elsif ($record->{'type'} eq 'MX') {
	return 0 if (!$class->CheckHostname($record->{'key'}));
	return 0 if (!$class->CheckHostameInZone($record->{'key'},$record->{'zone'}));
	return 0 if (!$class->CheckHostnameRelativity($record->{'value'},$record->{'zone'}));
	# format: 'priority server.name'
	if ($record->{'value'} =~ /^[\t ]*([^\t ]+)[\t ]+(.*)$/) {
	    return 0 if (!$class->CheckHostname($2));
	    return 0 if (!$class->CheckMXPriority($1));
	    return 1;
	} else {
	    # Popup error message, Checking MX (Mail eXchange) record format
	    Report->Error(__("Invalid MX record.
Use the format 'priority server-name'.
"));
	    return 0;
	}
    }
    # FIXME: TXT and SRV records

    y2warning("Undefined record type '".$record->{'type'}."'");
    return 1;
}

=item *
C<$integer = TimeToSeconds($string);>

Gets the BIND time parameter and transforms it into seconds.

EXAMPLE:

    my $time = TimeToSeconds("1W2d4H");

=cut

BEGIN{$TYPEINFO{TimeToSeconds} = ["function", "integer", "string"]};
sub TimeToSeconds {
    my $class        = shift;
    my $originaltime = shift || '';

    return undef if !Init();

    my $time      = $originaltime;
    my $totaltime = 0;
    while ($time =~ s/^(\d+)([WDHMS])//i) {
	if ($2 eq 'W' || $2 eq 'w') {
	    $totaltime += $1 * 604800;
	} elsif ($2 eq 'D' || $2 eq 'd') {
	    $totaltime += $1 * 86400;
	} elsif ($2 eq 'H' || $2 eq 'h') {
	    $totaltime += $1 * 3600;
	} elsif ($2 eq 'M' || $2 eq 'm') {
	    $totaltime += $1 * 60;
	} elsif ($2 eq 'S' || $2 eq 's') {
	    $totaltime += $1;
	}
    }
    if ($time =~ s/^(\d+)$//) {
	$totaltime += $1;
    }
    if ($time ne '') {
	y2error("Wrong time format '".$originaltime."', unable to parse.");
	return undef;
    }

    return $totaltime;
}

=item *
C<$string = SecondsToHighestTimeUnit($integer);>

Gets the time in seconds and returns BIND time format with
the highest possible time unit selected.

EXAMPLE:

    my $bind_time = SecondsToHighestTimeUnit(259200);
    -> "3D"

=cut

BEGIN{$TYPEINFO{SecondsToHighestTimeUnit} = ["function", "string", "integer"]};
sub SecondsToHighestTimeUnit {
    my $class   = shift;
    my $seconds = shift || 0;

    return undef if !Init();

    if ($seconds <= 0) {
	return $seconds;
    }

    my $units = {
	'W' => 604800,
	'D' => 86400,
	'H' => 3600,
	'M' => 60,
	'S' => 1,
    };

    foreach my $unit ('W', 'D', 'H', 'M', 'S') {
	if ($seconds % $units->{$unit} == 0) {
	    return (($seconds / $units->{$unit}).$unit);
	}
    }
}

sub CheckBINDTimeValue {
    my $class = shift;
    my $key   = shift || '';
    my $time  = shift || '';

    # translate bind time to seconds
    $time = $class->TimeToSeconds($time) || do {
	# undef returned
	return 0 if ($time eq undef);
    };

    if ($key eq 'ttl') {
	# RFC 2181
	if ($time < 0 || $time > 2147483647) {
	    # TRANSLATORS: Popup error message, Checking time value for specific SOA section (key),
	    #   %1 is the section name, %2 is the minimal value, %3 si the maximal value of the section
	    Report->Error(sformat(__("Invalid SOA record.
%1 must be from %2 to %3 seconds.
"), $key, 0, 2147483647));
	    return 0;
	}
	return 1;
    } elsif ($key eq 'minimum') {
	# RFC 2308, BIND 9 specific
	if ($time < 0 || $time > 10800) {
	    # TRANSLATORS: Popup error message, Checking time value for specific SOA section (key),
	    #   %1 is the section name, %2 is the minimal value, %3 si the maximal value of the section
	    Report->Error(sformat(__("Invalid SOA record.
%1 must be from %2 to %3 seconds.
"), $key, 0, 10800));
	    return 0;
	}	
    }

    return 1;
}

sub CheckBINDTimeFormat {
    my $class = shift;
    my $key   = shift || '';
    my $time  = shift || '';

    # must be defined (non-empty string)
    if ($time ne '' && (
	# number with suffix and combinations, case insensitive
	$time =~ /^(\d+W)?(\d+D)?(\d+H)?(\d+M)?(\d+S)?$/i
	||
	# only number
	$time =~ /^\d+$/
    )) {
	return 1;
    }

    # TRANSLATORS: Popup error message, Checking special BIND time format consisting of numbers
    #   and defined suffies, also only number (as seconds) is allowed, %1 is a section name
    #   like 'ttl' or 'refresh'
    Report->Error(sformat(__("Invalid SOA record.
%1 must be a BIND time type.
A BIND time type consists of numbers and the case-insensitive
suffixes W, D, H, M, and S. Time in seconds is allowed without the suffix.
Enter values such as 12H15m, 86400, or 1W30M.
"), $key));
    return 0;
}

sub CheckBINDTime {
    my $class = shift;
    my $key   = shift || '';
    my $time  = shift || '';

    return 0 if (!$class->CheckBINDTimeFormat($key,$time));
    return 0 if (!$class->CheckBINDTimeValue ($key,$time));
    return 1;
}

sub CheckSOARecord {
    my $class = shift;
    my $key   = shift || '';
    my $value = shift || '';

    # only number
    if ($key eq 'serial') {
	# 32 bit unsigned integer
	my $max_serial = 4294967295;
	if ($value !~ /^\d+$/ || $value > $max_serial) {
	    # TRANSLATORS: Popup error message, Checking SOA record,
	    #   %1 is a part of SOA, %2 is typically 0, %3 is some huge number
	    Report->Error(sformat(__("Invalid SOA record.
%1 must be a number from %2 to %3.
"), 'serial', 0, $max_serial));
	    return 0;
	}
	return 1;
    # BIND time type
    } else {
	return 0 if (!$class->CheckBINDTime($key,$value));
	return 1;
    }
}

# Function returns quoted string by a double-quote >>"<<
# 'A"b"Cd42' -> '"A\"b\"Cd42"'
sub QuoteString {
    my $class = shift;
    
    my $string = shift || '';
    my $quote  = '"';

    $string =~ s/\\/\\\\/g;
    $string =~ s/$quote/\\$quote/g;
    $string = $quote.$string.$quote;

    return $string;
}

sub UnquoteString {
    my $class = shift;
    
    my $string = shift || '';
    my $quote  = '"';

    $string =~ s/^$quote//;
    $string =~ s/$quote$//;
    $string =~ s/\\$quote/$quote/g;
    $string =~ s/\\\\/\\/g;

    return $string;
}

sub Init {
    if ($package_installed != -1){
        return $package_installed;
    }

    $package_installed = PackageSystem->Installed('yast2-dns-server');
    y2milestone("PackageSystem->Installed: ", $package_installed);
    if ($package_installed == 0){
        y2warning("yast2-dns-server is not installed. Functions of DnsServerAPI will be disabled") 
    }
    return $package_installed;
}

# GLOBAL FUNCTIONS >>>

BEGIN{$TYPEINFO{StopDnsService} = ["function", "boolean", ["map", "string", "any"]];}
sub StopDnsService {

    my $self = shift;
    my $config_options = shift;

    return undef if !Init();

    return DnsServer->StopDnsService ();
}

BEGIN{$TYPEINFO{StartDnsService} = ["function", "boolean", ["map", "string", "any"]];}
sub StartDnsService {
    my $self = shift;
    my $config_options = shift;

    return undef if !Init();

    return DnsServer->StartDnsService ();
}

BEGIN{$TYPEINFO{GetDnsServiceStatus} = ["function", "boolean", ["map", "string", "any"]];}
sub GetDnsServiceStatus {
    my $self = shift;
    my $config_options = shift;

    return undef if !Init();

    return DnsServer->GetDnsServiceStatus ();
}

=item *
C<$boolean = Read($time);>

Reads current BIND configuration.

EXAMPLE:

    my $success = Read();

=cut

BEGIN{$TYPEINFO{Read} = ["function", "boolean"]};
sub Read {
    my $class = shift;
   
    return undef if !Init();

    my $progress_orig = Progress->set (0);
    my $ret = DnsServer->Read ();

    Progress->set ($progress_orig);

    return $ret;
}

=item *
C<$boolean = Write($time);>

Writes current BIND configuration.

EXAMPLE:

    my $success = Write();

=cut

BEGIN{$TYPEINFO{Write} = ["function", "boolean"]};
sub Write {
    my $class = shift;
    
    return undef if !Init();

    my $progress_orig = Progress->set (0);
    my $ret = DnsServer->Write ();
    Progress->set ($progress_orig);

    return $ret;
}

=item *
C<@array = GetForwarders();>

Returns list of general DNS forwarders.

EXAMPLE:

    my $list_of_forwarders = GetForwarders();

=cut

BEGIN{$TYPEINFO{GetForwarders} = ["function", ["list", "string"]]};
sub GetForwarders {
    my $class = shift;

    return undef if !Init();

    my $options = DnsServer->GetGlobalOptions();
    my $forwarders = '';
    my @ret;
    foreach (@{$options}) {
	if ($_->{'key'} eq 'forwarders') {
	    $forwarders = $_->{'value'};
	    @ret = GetListFromRecord($_->{'value'});
	    last;
	}
    }

    return \@ret;
}

=item *
C<$boolean = AddForwarder($ipv4);>

Adds a new forwarder into the list of current forwarders.

EXAMPLE:

    my $success = AddForwarder($forwarder_ip);

=cut

BEGIN{$TYPEINFO{AddForwarder} = ["function", "boolean", "string"]};
sub AddForwarder {
    my $class = shift;
    my $new_one = shift || '';

    return undef if !Init();

    return 0 if (!$class->CheckIPv4($new_one));

    my $forwarders = $class->GetForwarders();
    if (!DnsServer->contains($forwarders, $new_one)) {
	push @{$forwarders}, $new_one;

	my $options = DnsServer->GetGlobalOptions();
	my $current_record = 0;
	foreach (@{$options}) {
	    if ($_->{'key'} eq 'forwarders') {
		@{$options}[$current_record] = {
		    'key' => 'forwarders',
		    'value' => GetRecordFromList(@{$forwarders}),
		};
		last;
	    }
	    ++$current_record;
	}
	DnsServer->SetGlobalOptions($options);
	return 1;
    }

    return 1;
}

=item *
C<$boolean = RemoveForwarder($ipv4);>

Removes forwarder from the list of current forwarders.

EXAMPLE:

    my $success = RemoveForwarder($forwarder_ip);

=cut

BEGIN{$TYPEINFO{RemoveForwarder} = ["function", "boolean", "string"]};
sub RemoveForwarder {
    my $class = shift;
    my $remove_this = shift || '';

    return undef if !Init();

    my $forwarders = $class->GetForwarders();
    if (grep { /^$remove_this$/ } @{$forwarders}) {
	@{$forwarders} = grep { $_ ne $remove_this } @{$forwarders};

	my $options = DnsServer->GetGlobalOptions();
	my $current_record = 0;
	foreach (@{$options}) {
	    if ($_->{'key'} eq 'forwarders') {
		@{$options}[$current_record] = {
		    'key' => 'forwarders',
		    'value' => GetRecordFromList(@{$forwarders}),
		};
		last;
	    }
	    ++$current_record;
	}
	DnsServer->SetGlobalOptions($options);
	return 1;
    }

    return 1;
}

=item *
C<$boolean = IsLoggingSupported();>

Checks whether the current configuration is supported by functions for getting
or changing configuration by this module. User should be warned that his
configuration could get demaged if he change it by this module.

Only one logging channel is supported.

EXAMPLE:

    my $is_supported = IsLoggingSupported($forwarder_ip);

=cut

BEGIN{$TYPEINFO{IsLoggingSupported} = ["function", "boolean"]};
sub IsLoggingSupported {
    my $class = shift;
    
    return undef if !Init();

    my $logging = DnsServer->GetLoggingOptions();
    # only one channel is supported
    my $number_of_channels = 0;
    # only one channel for one category is supported
    my $more_channels_at_once = 0;

    foreach (@{$logging}) {
	if ($_->{'key'} eq 'channel') {
	    ++$number_of_channels;
	} elsif ($_->{'key'} eq 'category') {
	    my $used_channels = $_->{'value'};
	    $used_channels =~ s/(^[\t ]*[^\t ]+[\t ]*\{[\t ]*|[\t ;]+\}[\t ]*$)//g;
	    my @count_of_channels_at_once = split(';',$used_channels);
	    if (scalar(@count_of_channels_at_once)>1) { $more_channels_at_once = 1; }
	}
    }

    if ($number_of_channels>1 || $more_channels_at_once!=0) {
	return 0;
    }
    return 1;
}

=item *
C<$hash = GetLoggingChannel();>

Returns hash with current logging channel.

EXAMPLE:

  my $channel = GetLoggingChannel();
  if ($channel->{'destination'} eq 'syslog') {
    print "logging to syslog is used";
  } elsif ($channel->{'destination'} eq 'file') {
    print
      "logging to file is used\n".
      " File: ".$channel->{'filename'}.
      " Max. Versions: ".$channel->{'versions'}.
      " Max. Size: ".$channel->{'size'};
  }

=cut

BEGIN{$TYPEINFO{GetLoggingChannel} = ["function", ["map", "string", "string"]]};
sub GetLoggingChannel {
    my $class = shift;
    
    return undef if !Init();

    my $logging_ret = {
	'destination' => '',
	'filename' => '',
	'size' => '0',
	'versions' => '0',
    };

    my $logging = DnsServer->GetLoggingOptions();
    foreach (@{$logging}) {
	if ($_->{'key'} eq 'channel') {
	    my $log_channel = $_->{'value'};
	    if ($log_channel =~ /\{[\t ]*syslog;[\t ]*\}/) {
		$logging_ret->{'destination'} = 'syslog';
		last;
	    } elsif ($log_channel =~ /\{[\t ]*file[\t ]*/ ) {
		$logging_ret->{'destination'} = 'file';
		# remove starting and ending brackets, spaces and channel name
		$log_channel =~ s/(^[^{]+\{[\t ]*|[\t ]*;[\t ]*\}.*$)//g;

		# to prevent from jammed system
		my $max_loop = 10;
		while ($max_loop>0 && $log_channel =~ s/((file)[\t ]+(\"(\\"|[^\"])*\")|(versions)[\t ]+([^\t ])+|(size)[\t ]+([^\t ]+))//) {
		    if ($2) {
			$logging_ret->{'filename'} = $class->UnquoteString($3);
		    } elsif ($5) {
			$logging_ret->{'versions'} = $6;
		    } elsif ($7) {
			$logging_ret->{'size'} = $8;
		    }
		    --$max_loop;
		}
		last;
	    }
	}
    }

    return $logging_ret;
}

=item *
C<$boolean = SetLoggingChannel($hash);>

Returns hash with current logging channel.

EXAMPLE:

  if ($log_to_syslog) {
    $success = SetLoggingChannel(
      'destination' => 'syslog'
    );
  } else {
    $success = SetLoggingChannel(
      'destination' => 'file',
      'filename'    => '/var/log/named.log',
      'versions'    => '8',
      'size'        => '10M',
    );
  }

=cut

BEGIN{$TYPEINFO{SetLoggingChannel} = ["function", "boolean", ["map", "string", "string"]]};
sub SetLoggingChannel {
    my $class = shift;
    my $channel = shift || {};

    return undef if !Init();

#   $channel_params = {
#	'destination' => '', (file|syslog)
#	'filename' => '',    (filename,   needed for 'file')
#	'size' => '0',       (any string, needed for 'file')
#	'versions' => '0',   (any string, needed for 'file')
#   };

    # checking destination
    if (not defined $channel->{'destination'} || $channel->{'destination'} !~ /^(file|syslog)$/) {
	y2error("'destination' must be 'file' or 'syslog'");
	return 0;
    }
    # checking logfile settings
    if ($channel->{'destination'} eq 'file') {
	if (not defined $channel->{'filename'} || $channel->{'filename'} eq '') {
	    # TRANSLATORS: Popup error message, parameters validation, 'filename' is needed parameter
	    Report->Error(__("The filename must be defined when logging to a file."));
	    return 0;
	}
	# checking logfile size
	if (not defined $channel->{'size'}) {
	    $channel->{'size'} = 0;
	} elsif ($channel->{'size'} !~ /^\d+[kKmMgG]?$/) {
	    # TRANSLATORS: Popup error message, parameters validation, wrongly set file size
	    Report->Error(__("Invalid file size.

It must be set in the format 'number[suffix]'.

Possible suffixes are k, K, m, M, g, and G.
"));
	    return 0;
	}
	# checking logfile versions
	if (not defined $channel->{'versions'}) {
	    $channel->{'versions'} = 0;
	} elsif ($channel->{'versions'} !~ /^\d+$/) {
	    # TRANSLATORS: Popup error message, parameters validation, wrongly set number of versions
	    Report->Error(__("The count of file versions must be a number."));
	    return 0;
	}
    }

    my $channel_string = '';
    my $channel_name = '';
    if ($channel->{'destination'} eq 'file') {
	$channel_name = $SETTINGS->{'logging_channel_file'};
	$channel_string = $channel_name.' { '.
	    'file '.$class->QuoteString($channel->{'filename'}).
	    ($channel->{'versions'} ? ' versions '.$channel->{'versions'} : '').
	    ($channel->{'size'}     ? ' size '.$channel->{'size'}         : '').
	'; }';
    } else {
	$channel_name = $SETTINGS->{'logging_channel_syslog'};
	$channel_string = $channel_name.' { syslog; }';
    }


    my @new_logging = {
	'key'   => 'channel',
	'value' => $channel_string
    };

    # changing logging channel for every used cathegory
    my $categories = $class->GetLoggingCategories();
    foreach (@{$categories}) {
	push @new_logging, {
	    'key' => 'category',
	    'value' => $_.' { '.$channel_name.'; }'
	};
    }

    DnsServer->SetLoggingOptions(\@new_logging);
    return 1;
}

=item *
C<$array = GetLoggingCategories();>

Returns list of used logging categories.

EXAMPLE:

  my $categories = GetLoggingCategories();
  foreach my $category (@{$categories}) {
    print "Using category: ".$category."\n";
  }

=cut

BEGIN{$TYPEINFO{GetLoggingCategories} = ["function", ["list", "string"]]};
sub GetLoggingCategories {
    my $class = shift;

    return undef if !Init();

    my @used_categories;
    my $logging = DnsServer->GetLoggingOptions();

    foreach (@{$logging}) {
	if ($_->{'key'} eq 'category') {
	    $_->{'value'} =~ /^[\t ]*([^\t ]+)[\t ]/;
	    if ($1) {
		push @used_categories, $1;
	    } else {
		y2warning("Unknown category format '".$_->{'value'}."'");
	    }
	}
    }

    return \@used_categories;
}

=item *
C<$boolean = SetLoggingCategories($array);>

Returns list of used logging categories.

EXAMPLE:

  my @categories = ('default', 'xfer-in');
  my $success = SetLoggingCategories(\@categories);

=cut

BEGIN{$TYPEINFO{SetLoggingCategories} = ["function", "boolean", ["list", "string"]]};
sub SetLoggingCategories {
    my $class = shift;
    my $categories = shift;

    return undef if !Init();

    my $logging_channel = '';
    # we need the destination to be set for each category
    my $channel = $class->GetLoggingChannel();
    if ($channel->{'destination'} eq 'file') {
	$logging_channel = $SETTINGS->{'logging_channel_file'};
    } else {
	$logging_channel = $SETTINGS->{'logging_channel_syslog'};
    }

    my @new_logging;

    # 'default' category should be used allways
    # that's the default for BIND in SUSE
    if (!DnsServer->contains($categories, 'default')) {
	push @{$categories}, 'default';
    }
    
    # defining the chanel
    my $logging = DnsServer->GetLoggingOptions();
    foreach (@{$logging}) {
	if ($_->{'key'} eq 'channel') {
	    push @new_logging, $_;
	    last;
	}
    }
    # defining categories
    foreach (@{$categories}) {
	push @new_logging, {
	    'key'   => 'category',
	    'value' => $_.' { '.$logging_channel.'; }',
	};
    }

    DnsServer->SetLoggingOptions(\@new_logging);
    return 1;
}

BEGIN{$TYPEINFO{GetNamedOptions} = ["function", ["list", ["map", "string", "string"]]]};
sub GetNamedOptions {
    my $class = shift;
    
    return undef if !Init();

    return DnsServer->GetGlobalOptions();;
}

BEGIN{$TYPEINFO{GetKnownNamedOptions} = ["function", ["map", "string", ["map", "string", "string"]]]};
sub GetKnownNamedOptions {
    return undef if !Init();

    return $OPTIONS;
}

BEGIN{$TYPEINFO{AddNamedOption} = ["function", "boolean", "string", "string", "boolean"]};
sub AddNamedOption {
    my $class = shift;

    my $option = shift;
    my $value  = shift;
    my $force  = shift; # 1 = do not check the syntax

    # FIXME: add an option, SLES

    y2error("NOT IMPLEMENTED YET - SLES FUNCTIONALITY");
}

BEGIN{$TYPEINFO{RemoveNamedOption} = ["function", "boolean", "string", "string"]};
sub RemoveNamedOption {
    my $class = shift;

    my $option = shift;
    my $value  = shift;

    # FIXME: remove an option, SLES

    y2error("NOT IMPLEMENTED YET - SLES FUNCTIONALITY");
}

=item *
C<$hash = GetACLs();>

Returns hash of possible ACLs.

EXAMPLE:

  my $acls = GetACLs();
  foreach $acl_name (keys %{$acls}) {
    if (defined $acls->{$acl_name}->{'default'}) {
	# names: 'any', 'none', 'localnets', 'localips'
	print "Default: ".$acl_name."\n";
    } else {
	print
	    "Custom: ".$acl_name." ".
	    "Value: ".$acls->{$acl_name}->{'value'}."\n";
    }
  }

=cut

BEGIN{$TYPEINFO{GetACLs} = ["function", ["map", "string", ["map", "string", "string"]]]};
sub GetACLs {
    my $class = shift;

    return undef if !Init();

    my $return_acls = {
	'any'       => { 'default' => 'yes' },
	'none'      => { 'default' => 'yes' },
	'localnets' => { 'default' => 'yes' },
	'localips'  => { 'default' => 'yes' },
    };

    my $acls = DnsServer->GetAcl();
    foreach my $acl (@{$acls}) {
	#local_ips { 10.20.15.0/20; }
	#friends { 147.8.12.153; 85.15.98.16; 235.8.146.1; }
	$acl =~ /^([^\t ]+)[\t ]*\{([^\}]*)\}/;
	my $name  = $1;
	my $value = $2;
	$value =~ s/(^[\t ]*|[\t ]*$)//g;

	if ($name) {
	    $return_acls->{$name} = { 'value' => $value };
	} else {
	    y2warning("Unknown ACL format '".$acl."'");
	}
    }

    return $return_acls;
}

=item *
C<$hash = GetZones($string);>

Returns all DNS zones administered by this DNS server.

EXAMPLE:

  my $zones = GetZones();
  foreach my $zone (keys %{$zones}) {
    print
      "Zone Name: ".$zone." ".
      "Zone Type: ".$zones->{$zone}->{'type'}."\n"; # 'master' or 'slave'
  }

=cut

BEGIN{$TYPEINFO{GetZones} = ["function", ["map", "string", ["map", "string", "string"]]]};
sub GetZones {
    my $class = shift;

    return undef if !Init();

    my $zones_return = {};
    my $zones = DnsServer->FetchZones();
    foreach (@$zones) {
	# skipping default (local) zones
	next if ($_->{'zone'} =~ /^(0\.0\.127\.in-addr\.arpa|\.|localhost)$/);
	$zones_return->{$_->{'zone'}}->{'type'} = $_->{'type'};
    }

    return $zones_return;
}

=item *
C<$array = GetZoneMasterServers($string);>

Returns list of master servers assigned to this slave zone.
Master zones do not have any master servers defined.

EXAMPLE:

  my $zone = 'example.org';
  foreach my $server @(GetZoneMasterServers($zone)) {
    print "Zone ".$zone." uses ".$server." master server\n";
  }

=cut

BEGIN{$TYPEINFO{GetZoneMasterServers} = ["function", ["list", "string"], "string"]};
sub GetZoneMasterServers {
    my $class = shift;
    my $zone  = shift || '';

    return undef if !Init();

    return 0 if (!$class->CheckZone($zone));

    my @masters;
    my $zones = DnsServer->FetchZones();
    foreach (@$zones) {
	if ($zone eq $_->{'zone'}) {
	    if ($_->{'type'} eq 'slave') {
		@masters = GetListFromRecord($_->{'masters'});
		last;
	    } else {
		# TRANSLATORS: Popup error message, Trying to get 'master server' for zone which is not 'slave' type,
		#   'master' servers haven't any 'masterservers', they ARE masterservers
		#   %1 is name of the zone, %2 is type of the zone
		Report->Error(sformat(__("Only slave zones have a master server defined.
Zone %1 is type %2.
"), $_->{'zone'}, $_->{'type'}));
	    }
	}
    }

    return \@masters;
}

=item *
C<$boolean = SetZoneMasterServers($string,$array);>

Sets masterservers for slave zone.

EXAMPLE:

  my @masterservers = ('192.168.32.1','192.168.32.2');
  my $zone = 'example.org';
  my $success = SetZoneMasterServers($zone, \@masterservers);

=cut

BEGIN{$TYPEINFO{SetZoneMasterServers} = ["function", "boolean", "string", ["list", "string"]]};
sub SetZoneMasterServers {
    my $class   = shift;
    my $zone    = shift || '';
    my $masters = shift;

    return undef if !Init();

    return 0 if (!$class->CheckZone($zone));
    return 0 if (!$class->CheckIPv4s($masters));

    my $zones = DnsServer->FetchZones();
    my $zone_counter = 0;
    foreach my $one_zone (@{$zones}) {
	if ($zone eq $one_zone->{'zone'}) {
	    if ($one_zone->{'type'} eq 'slave') {
		$one_zone->{'masters'} = GetRecordFromList(@{$masters});
		$one_zone->{'modified'} = 1;
		@{$zones}[$zone_counter] = $one_zone;
		DnsServer->StoreZones($zones);
		last;
	    } else {
		# TRANSLATORS: Popup error message, Trying to set 'master server' for zone which is not 'slave' type,
		#   %1 is name of the zone, %2 is type of the zone
		Report->Error(sformat(__("Only slave zones have a master server defined.
Zone %1 is type %2.
"), $one_zone->{'zone'}, $one_zone->{'type'}));
	    }
	}
	++$zone_counter;
    }

    return 1;
}

=item *
C<$boolean = AddZone($string,$string,$hash);>

Function creates new DNS zone. Option 'masterserver' is needed
for 'slave' zone.

EXAMPLE:

  # 'master' zone
  $success = AddZone(
    'example.org', # zone name
    'master',      # zone type
    {}             # without options
  );
  
  # 'slave' zone
  $success = AddZone(
    'example.org', # zone name
    'slave',       # zone type
    {              # 'masterserver' must be defined for 'slave' zone
	'masterserver' => '192.168.64.2'
    }
  );

=cut

BEGIN{$TYPEINFO{AddZone} = ["function", "boolean", "string", "string", ["map", "string", "string"]]};
sub AddZone {
    my $class   = shift;

    my $zone    = shift || '';
    my $type    = shift || '';
    my $options = shift || {};

    return undef if !Init();

    # zone name must be defined
    if (!$zone) {
	# TRANSLATORS: Popup error message, Calling function which needs DNS zone defined
	Report->Error(__("The zone name must be defined."));
	return 0;
    }

    # zone mustn't exist already
    my $zones = $class->GetZones();
    foreach my $known_zone (keys %{$zones}) {
	if ($zone eq $known_zone) {
	    # TRANSLATORS: Popup error message, Trying to add new zone which already exists
	    Report->Error(sformat(__("Zone name %1 already exists."), $zone));
	    return 0;
	}
    }

    return 0 if (!$class->CheckZoneType($type));

    if ($type eq 'slave' && !$options->{'masterserver'}) {
	# TRANSLATORS: Popup error message, Adding new 'slave' zone without defined needed option 'masterserver'
	Report->Error(__("Option masterserver is needed for slave zones."));
	return 0;
    }

    DnsServer->SelectZone(-1);
    my $new_zone = DnsServer->FetchCurrentZone();
    $new_zone->{'zone'} = $zone;
    $new_zone->{'type'} = $type;
    DnsServer->StoreCurrentZone($new_zone);
    DnsServer->StoreZone();

    if ($type eq 'slave') {
	my @masters = $options->{'masterserver'};
	$class->SetZoneMasterServers($zone, \@masters);
    } elsif ($type eq 'forward') {
	# forwarders are optional for 'forward' zone
	if (defined $options->{'forwarders'}) {
	    $options->{'forwarders'} =~ s/,/ /g;
	    $options->{'forwarders'} =~ s/;/ /g;
	    $options->{'forwarders'} =~ s/ +/ /g;
	    $options->{'forwarders'} =~ s/(^ *| *$)//g;
	    
	    my @forwarders = split(/ /, $options->{'forwarders'});
	    $class->SetZoneForwarders($zone, \@forwarders);
	}
    }

    return 1;
}

=item *
C<$boolean = RemoveZone($string);>

Function removes a zone.

EXAMPLE:

    $success = RemoveZone('example.org');

=cut

BEGIN{$TYPEINFO{RemoveZone} = ["function", "boolean", "string"]};
sub RemoveZone {
    my $class = shift;
    my $zone = shift || '';

    return undef if !Init();

    return 0 if (!$class->CheckZone($zone));

    my $zones = DnsServer->FetchZones();
    my @new_zones;
    foreach (@{$zones}) {
	# skipping zone to be deleted
	next if ($_->{'zone'} eq $zone);
	push @new_zones, $_;
    }
    DnsServer->StoreZones(\@new_zones);

    return 1;
}

=item *
C<$array = GetZoneTransportACLs($string);>

Function returns list of ACLs used for Zone Transportation.

EXAMPLE:

  my $acls = GetZoneTransportACLs('example.org');
  foreach my $acl_name (@{$acls}) {
    print "ACL used: ".$acl_name."\n";
  }

=cut

BEGIN{$TYPEINFO{GetZoneTransportACLs} = ["function", ["list", "string"], "string"]};
sub GetZoneTransportACLs {
    my $class = shift;
    my $zone  = shift || '';

    return undef if !Init();

    return 0 if (!$class->CheckZone($zone));
    
    my @used_acls;
    my $zones = DnsServer->FetchZones();
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    foreach (@{$_->{'options'}}) {
		if ($_->{'key'} eq 'allow-transfer') {
		    @used_acls = GetListFromRecord($_->{'value'});
		    last;
		}
	    }
	    last;
	}
    }

    return \@used_acls;
}

# hidden function
sub SetZoneTransportACLs {
    my $class = shift;
    my $zone  = shift || '';
    my $acls  = shift;

    return 0 if (!$class->CheckZone($zone));

    my $zones = DnsServer->FetchZones();
    my $zone_counter = 0;
    foreach my $one_zone (@{$zones}) {
	if ($one_zone->{'zone'} eq $zone) {
	    my @new_options;
	    foreach (@{$one_zone->{'options'}}) {
		# removing all allow-transfer from options, getting allow-transfer
		if ($one_zone->{'key'} eq 'allow-transfer') {
		    next;
		} else {
		# adding all non-allow-transfer from options
		    push @new_options, $one_zone;
		}
	    }
	    push @new_options, { 'key' => 'allow-transfer', 'value' => GetRecordFromList(@{$acls}) };
	    $one_zone->{'options'} = \@new_options;
	    $one_zone->{'modified'} = 1;
	    @{$zones}[$zone_counter] = $one_zone;
	    last;
	}
	++$zone_counter;
    }
    DnsServer->StoreZones($zones);

    return 1;
}

=item *
C<$boolean = AddZoneTransportACL($string,$string);>

Adds ACL into ACLs allowed for Zone Transportation.
ACL must be known (default or custom).

EXAMPLE:

    my $success = AddZoneTransportACL('example.org','localnets');

=cut

BEGIN{$TYPEINFO{AddZoneTransportACL} = ["function", "boolean", "string", "string"]};
sub AddZoneTransportACL {
    my $class = shift;
    my $zone  = shift || '';
    my $acl   = shift || '';

    return undef if !Init();

    return 0 if (!$class->CheckZone($zone));
    return 0 if (!$class->CheckTransportACL($acl));

    my @used_acls = ToSet(@{$class->GetZoneTransportACLs($zone)}, $acl);
    $class->SetZoneTransportACLs($zone, \@used_acls);
}

=item *
C<$boolean = RemoveZoneTransportACL($string,$string);>

Removes ACL from ACLs allowed for Zone Transportation.
ACL must be known (default or custom).

EXAMPLE:

    my $success = RemoveZoneTransportACL('example.org','localnets');

=cut

BEGIN{$TYPEINFO{RemoveZoneTransportACL} = ["function", "boolean", "string", "string"]};
sub RemoveZoneTransportACL {
    my $class = shift;
    my $zone  = shift || '';
    my $acl   = shift || '';

    return undef if !Init();

    return if (!$class->CheckZone($zone));
    return 0 if (!$class->CheckTransportACL($acl));

    my @used_acls = ToSet(@{$class->GetZoneTransportACLs($zone)}, $acl);
    @used_acls = grep { !/^$acl$/ } @used_acls;
    $class->SetZoneTransportACLs($zone, \@used_acls);
}

sub GetZoneRecords {
    my $class = shift;
    my $zone  = shift || '';
    my $types = shift; # none means all types

    return 0 if (!$class->CheckZone($zone));

    my $check_types = 0;
    $check_types = 1 if (scalar(@{$types})>0);

    my @records;
    my $zones = DnsServer->FetchZones();
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    foreach (@{$_->{'records'}}) {
		if ($check_types) {
		    # skipping record if type doesn't match
		    my $type = $_->{'type'};
		    next if (!DnsServer->contains($types, $type));
		}
		push @records, $_;
	    }
	    last;
	}
    }

    return \@records;
}

=item *
C<$array = GetZoneNameServers($string);>

Function returns list of Zone Name Servers.
Only Zone base name servers are returned.

EXAMPLE:

    my $nameservers = GetZoneNameServers('example.org');

=cut

BEGIN{$TYPEINFO{GetZoneNameServers} = ["function", ["list", "string"], "string"]};
sub GetZoneNameServers {
    my $class = shift;
    my $zone  = shift || '';

    return undef if !Init();

    return 0 if (!$class->CheckZone($zone));

    my @types = ('NS');
    my @nameservers;
    foreach (@{$class->GetZoneRecords($zone, \@types)}) {
	# xyz.com. (ending with a dot) - getting NS servers only for the whole domain
	push @nameservers, $_->{'value'} if ($_->{'key'} eq $zone.'.');
    }

    return \@nameservers;
}

=item *
C<$array = GetZoneMailServers($string);>

Function returns list of hashes of Zone Mail Servers.
Only Zone base mail servers are returned.

EXAMPLE:

  my $mailservers = GetZoneMailServers('example.org');
  foreach my $mailserver (@{$mailservers}) {
    print
	"Mail Server: ".$mailserver->{'name'}." ".
	"Priority: ".$mailserver->{'priority'};
  }

=cut

BEGIN{$TYPEINFO{GetZoneMailServers} = ["function", ["list", ["map", "string", "string"]], "string"]};
sub GetZoneMailServers {
    my $class = shift;
    my $zone  = shift || '';

    return undef if !Init();

    return 0 if (!$class->CheckZone($zone));

    my @types = ('MX');
    my @mailservers;
    foreach (@{$class->GetZoneRecords($zone, \@types)}) {
	# xyz.com. (ending with a dot) - getting MX servers only for the whole domain
	if ($_->{'key'} eq $zone.'.') {
	    if ($_->{'value'} =~ /[\t ]*(\d+)[\t ]+([^\t ]+)$/) {
		push @mailservers, {
		    'name'	=> $2,
		    'priority'	=> $1
		};
	    } else {
		y2error("Unknown MX server '".$_->{'value'}."'");
	    }
	}
    }

    return \@mailservers;
}

=item *
C<$array = GetZoneRRs($string);>

Returns list of hashes with all zone records inside.
Base Zone Name and Mail Servers are filtered out.

EXAMPLE:

  my $records = GetZoneRRs('example.org');
  foreach my $record (@{$records}) {
    print
	"Record:\n".
	"  Key: ".$record->{'key'}."\n".     # DNS Query
	"  Type: ".$record->{'type'}."\n".   # Resource Record Type
	"  Value: ".$record->{'value'}."\n"; # DNS Reply
  }

=cut

BEGIN{$TYPEINFO{GetZoneRRs} = ["function", ["list", ["map", "string", "string"]], "string"]};
sub GetZoneRRs {
    my $class = shift;
    my $zone  = shift || '';

    return undef if !Init();

    return 0 if (!$class->CheckZone($zone));

    my @records;
    my @types;
    foreach (@{$class->GetZoneRecords($zone,\@types)}) {
	# filtering zone NS
	next if ($_->{'type'} eq 'NS' && $_->{'key'} eq $zone.'.');
	# filtering zone MX
	next if ($_->{'type'} eq 'MX' && $_->{'key'} eq $zone.'.');
	# filtering zone ORIGIN
	next if ($_->{'type'} eq 'ORIGIN');
	push @records, $_;
    }

    return \@records;
}

=item *
C<$boolean = AddZoneRR($string,$string,$string,$string);>

Adds Zone Resource Record.

EXAMPLE:

  # absolute hostname
  $success = AddZoneRR(
    'example.org',         # zone name
    'A',                   # record type
    'dhcp25.example.org.', # record key / DNS query
    '192.168.2.25',        # record value / DNS reply
  );

  # hostname relative to the zone name
  $success = AddZoneRR(
    '2.168.192.id-addr.arpa', # zone name
    'PTR',                    # record type
    '25',                     # record key / DNS query
    'dhcp25.example.org.',    # record value / DNS reply
  );

=cut

BEGIN{$TYPEINFO{AddZoneRR} = ["function","boolean","string","string","string","string"]};
sub AddZoneRR {
    my $class = shift;

    my $zone  = shift || '';
    my $type  = uc(shift) || '';
    my $key   = lc(shift) || '';
    my $value = lc(shift) || '';

    return undef if !Init();

    return 0 if (!$class->CheckZone($zone));
    return 0 if (!$class->ZoneIsMaster($zone));

    if (!$type) {
	# TRANSLATORS: Popup error message, Trying to add record without defined type
	Report->Error("DNS resource record type must be defined.");
	return 0;
    }
    if (!$key) {
	# TRANSLATORS: Popup error message, Trying to add record without key
	Report->Error("DNS resource record key must be defined.");
	return 0;
    }
    if (!$value) {
	# TRANSLATORS: Popup error message, Trying to add record without value
	Report->Error("DNS resource record value must be defined.");
	return 0;
    }

    # replacing all spaces with one space char (MX servers are affected)
    $value =~ s/[\t ]+/ /g;

    return 0 if (!$class->CheckResourceRecord({
	'type' => $type, 'key' => $key, 'value' => $value, 'zone' => $zone
    }));

    my $zones = DnsServer->FetchZones();
    my @new_records;
    my $new_zone = {};
    my $zone_index = 0;
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    foreach (@{$_->{'records'}}) {
		# replacing all spaces with one space char (MX servers are affected)
		$_->{'value'} =~ s/[\t ]+/ /g;
		if ($_->{'type'} eq $type && $_->{'key'} eq $key && $_->{'value'} eq $value) {
		    # the same record exists already, just return true
		    return 1;
		}
	    }
	    @new_records = @{$_->{'records'}};
	    push @new_records, { 'type' => $type, 'key' => $key, 'value' => $value };
	    $new_zone = @{$zones}[$zone_index];
	    $new_zone->{'records'} = \@new_records;
	    $new_zone->{'modified'} = 1;
	    last;
	}
	++$zone_index;
    }
    @{$zones}[$zone_index] = $new_zone;
    DnsServer->StoreZones($zones);

    return 1;
}

=item *
C<$boolean = RemoveZoneRR($string,$string,$string,$string);>

Removes Zone Resource Record.

EXAMPLE:

  # absolute hostname
  $success = RemoveZoneRR(
    'example.org',         # zone name
    'A',                   # record type
    'dhcp25.example.org.', # record key / DNS query
    '192.168.2.25',        # record value / DNS reply
  );

  # hostname relative to the zone name
  $success = RemoveZoneRR(
    '2.168.192.id-addr.arpa',  # zone name
    'MX',                      # record type
    '2.168.192.id-addr.arpa.', # record key / DNS query
    '10 mx1.example.org.',     # record value / DNS reply
  );

=cut

BEGIN{$TYPEINFO{RemoveZoneRR} = ["function","boolean","string","string","string","string"]};
sub RemoveZoneRR {
    my $class = shift;

    my $zone  = shift || '';

    return undef if !Init();

    # lowering all values, types are allways uppercased
    my $type  = uc(shift) || '';
    my $key   = lc(shift) || '';
    my $value = lc(shift) || '';
    my $prio  = ''; # used for MX records

    return 0 if (!$class->CheckZone($zone));
    return 0 if (!$class->ZoneIsMaster($zone));

    if (!$type) {
	# TRANSLATORS: Popup error message, Trying to remove record without defined type
	Report->Error("DNS resource record type must be defined.");
	return 0;
    }
    if (!$key) {
	# TRANSLATORS: Popup error message, Trying to remove record without key
	Report->Error("DNS resource record key must be defined.");
	return 0;
    }
    if (!$value) {
	# TRANSLATORS: Popup error message, Trying to remove record without value
	Report->Error("DNS resource record value must be defined.");
	return 0;
    }

    $value =~ s/(^[\t ]+|[\t ]+$)//g;
    if ($type eq 'MX') {
	$value =~ s/^(\d+)[\t ]+([^\t ]*)$/$2/g;
	if ($1 ne '') {
	    $prio = $1;
	} else {
	    y2error("Unknown MX recod '".$key."/".$type."/".$value."'");
	}
    }

    my $zones = DnsServer->FetchZones();
    my @new_records;
    my $new_zone = {};
    my $zone_index = 0;
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    my $record_found = 0;
	    foreach (@{$_->{'records'}}) {
		# for backup
		my $this_record = {
		    'key'   => $_->{'key'},
		    'type'  => $_->{'type'},
		    'value' => $_->{'value'},
		};

		$_->{'prio'} = '';

		if ($_->{'type'} eq 'MX') {
		    # replacing all spaces with one space char (MX servers are affected)
		    $_->{'value'} =~ s/(^[\t ]+|[\t ]+$)//g;
		    $_->{'value'} =~ s/^(\d+)[\t ]+([^\t ]*)$/$2/g;
		    if ($1 ne '') {
			$_->{'prio'}  = $1;
		    } else {
			y2error("Unknown MX recod '".$_->{'key'}."/".$_->{'type'}."/".$_->{'value'}."'");
		    }
		}
		
		# lowering all values, types are allways uppercased
		$_->{'type'}  = uc($_->{'type'});
		$_->{'key'}   = lc($_->{'key'});
		$_->{'value'} = lc($_->{'value'});
		
		# matching
		if ($_->{'type'} eq $type) {
		
		    # non-MX record non-realtive
		    if ($_->{'type'} ne 'MX' &&
			    $_->{'key'} eq $key && $_->{'value'} eq $value) {
			# gottcha!
			$record_found = 1;
			next;
		    # MX record non-realtive
		    } elsif ($_->{'type'} eq 'MX' &&
			    $_->{'key'} eq $key && $_->{'prio'}.' '.$_->{'value'} eq $prio.' '.$value) {
			# gottcha!
			$record_found = 1;
			next;
		    # relative record
		    } else {
			# transform all relative names to their absolute form
			$_->{'key'}   = $class->GetFullHostname($zone, $_->{'key'});
			$key          = $class->GetFullHostname($zone, $key);
			$_->{'value'} = $class->GetFullHostname($zone, $_->{'value'});
			$value        = $class->GetFullHostname($zone, $value);
			
			# non-MX record realtive
			if ($_->{'type'} ne 'MX' &&
				$_->{'key'} eq $key && $_->{'value'} eq $value) {
			    # gottcha!
			    $record_found = 1;
			    next;
			# MX record realtive
			} elsif ($_->{'type'} eq 'MX' &&
				$_->{'key'} eq $key && $_->{'prio'}.' '.$_->{'value'} eq $prio.' '.$value) {
			    # gottcha!
			    $record_found = 1;
			    next;
			}
		    }
		}

		push @new_records, $this_record;
	    }
	    if (!$record_found) {
		# such record doesn't exist
		return 1;
	    }
	    $new_zone = @{$zones}[$zone_index];
	    $new_zone->{'records'} = \@new_records;
	    $new_zone->{'modified'} = 1;
	    last;
	}
	++$zone_index;
    }
    @{$zones}[$zone_index] = $new_zone;
    DnsServer->StoreZones($zones);

    return 1;
}

=item *
C<$boolean = AddZoneNameServer($zone,$nameserver);>

Adds zone nameserver into the zone.

EXAMPLE:

  # relative name of the nameserver to the zone name
  $success = AddZoneNameServer('example.org','ns1');
  # absolute name of the nameserver ended with a dot
  $success = AddZoneNameServer('example.org','ns2.example.org.');

=cut

BEGIN{$TYPEINFO{AddZoneNameServer} = ["function","boolean","string","string"]};
sub AddZoneNameServer {
    my $class = shift;

    my $zone   = shift || '';
    my $server = shift || '';

    return undef if !Init();

    # zone checking is done in AddZoneRR() function

    return $class->AddZoneRR($zone, 'NS', $zone.'.', $server);
}

=item *
C<$boolean = RemoveZoneNameServer($zone,$nameserver);>

Removes zone nameserver from the zone.

EXAMPLE:

  # relative name of the nameserver to the zone name
  $success = RemoveZoneNameServer('example.org','ns2');
  # absolute name of the nameserver ended with a dot
  $success = RemoveZoneNameServer('example.org','ns1.example.org.');

=cut

BEGIN{$TYPEINFO{RemoveZoneNameServer} = ["function","boolean","string","string"]};
sub RemoveZoneNameServer {
    my $class = shift;

    my $zone   = shift || '';
    my $server = shift || '';

    return undef if !Init();

    # zone checking is done in RemoveZoneRR() function

    return $class->RemoveZoneRR($zone, 'NS', $zone.'.', $server);
}

=item *
C<$boolean = AddZoneMailServer($zone,$mailserver,$priority);>

Adds zone nameserver into the zone.

EXAMPLE:

  # relative name of the mailserver to the zone name
  $success = AddZoneMailServer('example.org','mx1',0);
  # absolute name of the mailserver ended with a dot
  $success = AddZoneMailServer('example.org','mx2.example.org.',5555);

=cut

BEGIN{$TYPEINFO{AddZoneMailServer} = ["function","boolean","string","string","integer"]};
sub AddZoneMailServer {
    my $class = shift;

    my $zone   = shift || '';
    my $server = shift || '';
    my $prio   = shift || '';

    return undef if !Init();

    # zone checking is done in AddZoneRR() function

    return $class->AddZoneRR($zone, 'MX', $zone.'.', $prio.' '.$server);
}

=item *
C<$boolean = RemoveZoneMailServer($zone,$mailserver,$priority);>

Removes zone mailserver from the zone.

EXAMPLE:

  # relative name of the mailserver to the zone name
  $success = RemoveZoneMailServer('example.org','mx1',0);
  # absolute name of the mailserver ended with a dot
  $success = RemoveZoneMailServer('example.org','mx2.example.org.',5555);

=cut

BEGIN{$TYPEINFO{RemoveZoneMailServer} = ["function","boolean","string","string","integer"]};
sub RemoveZoneMailServer {
    my $class = shift;

    my $zone   = shift || '';
    my $server = shift || '';
    my $prio   = shift || '';

    return undef if !Init();

    # zone checking is done in RemoveZoneRR() function

    return $class->RemoveZoneRR($zone, 'MX', $zone.'.', $prio.' '.$server);
}

=item *
C<$hash = GetZoneSOA($zone);>

Adds zone nameserver into the zone.

EXAMPLE:

  # relative name of the mailserver to the zone name
  my $SOA = GetZoneSOA('example.org');
  foreach my $key ('minimum', 'expiry', 'serial', 'retry', 'refresh', 'mail', 'server', 'ttl') {
    print $key."=".$SOA->{$key}."\n";
  }

=cut

BEGIN{$TYPEINFO{GetZoneSOA} = ["function",["map","string","string"],"string"]};
sub GetZoneSOA {
    my $class = shift;
    my $zone  = shift || '';

    return undef if !Init();

    return {} if (!$class->CheckZone($zone));
    return {} if (!$class->ZoneIsMaster($zone));

    my $return = {};

    my $zones = DnsServer->FetchZones();
    foreach (@{$zones}) {
	if ($_->{'zone'} eq $zone) {
	    foreach my $key ('minimum', 'expiry', 'serial', 'retry', 'refresh', 'mail', 'server') {
		if (defined $_->{'soa'}->{$key}) {
		    $return->{$key} = $_->{'soa'}->{$key};
		}
	    }
	    if (defined $_->{'ttl'}) {
		$return->{'ttl'} = $_->{'ttl'};
	    }
	    last;
	}
    }

    return $return;
}

=item *
C<$hash = SetZoneSOA($zone, $soa);>

Adds zone nameserver into the zone.

EXAMPLE:

  # relative name of the mailserver to the zone name
  my $SOA = {
    'minimum' => '1d1H',
    'expiry'  => '1W2d',
    'serial'  => '1998121001',
    'retry'   => '3600',
    'refresh' => '3h5M4S',
    'mail'    => 'root.ns1.example.org.',
    'server'  => 'ns1.example.org.',
    'ttl'     => '2d1h',
  };
  my $success = SetZoneSOA('example.org', $SOA);

=cut

BEGIN{$TYPEINFO{SetZoneSOA} = ["function","boolean","string",["map","string","string"]]};
sub SetZoneSOA {
    my $class = shift;
    my $zone  = shift || '';
    my $SOA   = shift || {};

    return undef if !Init();

    return 0 if (!$class->CheckZone($zone));
    return 0 if (!$class->ZoneIsMaster($zone));

    my $zones = DnsServer->FetchZones();
    my $zone_index = 0;
    my $new_zone = {};
    foreach my $one_zone (@{$zones}) {
	if ($one_zone->{'zone'} eq $zone) {
	    my $new_SOA = $one_zone->{'soa'};
	    foreach my $key ('minimum', 'expiry', 'serial', 'retry', 'refresh', 'mail', 'server') {
		# changing current SOA with new values
		if (defined $SOA->{$key}) {
		    return 0 if (!$class->CheckSOARecord($key,$SOA->{$key}));
		    $new_SOA->{$key} = $SOA->{$key};
		}
	    }
	    $new_zone = $one_zone;
	    # ttl is defined in another place
	    if (defined $SOA->{'ttl'}) {
		$new_zone->{'ttl'} = $SOA->{'ttl'};
	    }
	    $new_zone->{'soa'} = $new_SOA;
	    $new_zone->{'modified'} = 1;
	    last;
	}
	++$zone_index;
    }
    @{$zones}[$zone_index] = $new_zone;
    DnsServer->StoreZones($zones);

    return 1;
}

=item *
C<$reversezone = GetReverseZoneNameForIP($hostname);>

Returns reverse zone for IPv4 if such zone is
administered by this DNS server.

EXAMPLE:

  my $reversezone = GetReverseZoneNameForIP('192.168.58.12');

=cut

BEGIN{$TYPEINFO{GetReverseZoneNameForIP} = ["function","string","string"]};
sub GetReverseZoneNameForIP {
    my $class = shift;
    my $ip    = shift || '';

    return undef if !Init();

    return undef if (!$class->CheckIPv4($ip));

    my $zones = $class->GetZones();
    my @reversezones = ();
    foreach my $zone (keys %{$zones}) {
	if ($zones->{$zone}->{'type'} eq 'master' && $zone =~ /\.in-addr\.arpa$/) {
	    push @reversezones, $zone;
	}
    }

    if (scalar(@reversezones)==0) {
	return '';
    }

    my $arpaaddr = 'in-addr.arpa';
    my $matchingzone = '';
    foreach my $part (split(/\./, $ip)) {
	$arpaaddr = $part.'.'.$arpaaddr;
	foreach my $zone (@reversezones) {
	    $matchingzone = $zone if ($arpaaddr eq $zone);
	}
    }

    return $matchingzone;
}

=item *
C<$reverseip = GetReverseIPforIPv4($ipv4);>

Returns reverse ip for IPv4.

EXAMPLE:

  my $reverseip = GetReverseIPforIPv4('192.168.58.12');
  -> '12.58.168.192.id-addr.arpa'

=cut

BEGIN{$TYPEINFO{GetReverseIPforIPv4} = ["function","string","string"]};
sub GetReverseIPforIPv4 {
    my $class = shift;
    my $ipv4  = shift || '';

    return undef if (!IP->Check($ipv4));

    my $reverseip = 'in-addr.arpa.';
    foreach my $part (split(/\./, $ipv4)) {
	$reverseip = $part.'.'.$reverseip;
    }

    return $reverseip;
}

=item *
C<$reverseip = GetFullIPv6($ipv6);>

Returns full-length ip IPv6.

EXAMPLE:

  my $reverseip = GetFullIPv6('3ffe:ffff::1');
  -> '3ffe:ffff:0000:0000:0000:0000:0000:0001'
  my $reverseip = GetFullIPv6('3ffe:ffff::210:a4ff:fe01:1');
  -> '3ffe:ffff:0000:0000:0210:a4ff:fe01:0001'
  my $reverseip = GetFullIPv6('3ffe:ffff::');
  -> '3ffe:ffff:0000:0000:0000:0000:0000:0000'
  my $reverseip = GetFullIPv6('::25');
  -> '0000:0000:0000:0000:0000:0000:0000:0025'

=cut

BEGIN{$TYPEINFO{GetFullIPv6} = ["function","string","string"]};
sub GetFullIPv6 {
    my $class = shift;
    my $ipv6  = shift || '';

    return undef if (!IP->Check6($ipv6));

    # :: means undefined amount of "0000"
    if ($ipv6 =~ /::/) {
	# before ::
	my $part_before = $ipv6;
	$part_before =~ s/(.*)::.*/$1/;

	# after ::
	my $part_after = $ipv6;
	$part_after =~ s/.*::(.*)/$1/;

	my @part_before_full = ();
	my @part_after_full = ();

	# parts before ::
	foreach my $part (split /:/, $part_before) {
	    push @part_before_full, $part;
	}

	# parts after ::
	foreach my $part (split /:/, $part_after) {
	    push @part_after_full, $part;
	}

	# how many "0000" means the ::
	my $zeros = 8 - (scalar (@part_before_full) + scalar (@part_after_full));
	# string of zeros
	$zeros = "0000:"x${zeros};
	$zeros =~ s/:$//;

	# create like-an-IPv6 string
	$ipv6 = join (":", @part_before_full);
	$ipv6 .= (scalar (@part_before_full) > 0 ? ":":"");
	$ipv6 .= $zeros;
	$ipv6 .= (scalar (@part_after_full) > 0 ? ":":"");
	$ipv6 .= join (":", @part_after_full);
    }

    my @ret = ();

    foreach my $part (split /:/, $ipv6) {
	push @ret, sprintf ("%04s", $part);
    }

    return join (":", @ret);
}

=item *
C<$reverseip = GetReverseIPforIPv6($ipv6);>

Returns reverse ip for IPv6.

EXAMPLE:

  my $reverseip = GetReverseIPforIPv6('3ffe:ffff::1');
  -> '1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.f.f.f.f.e.f.f.3.ip6.arpa.'
  my $reverseip = GetReverseIPforIPv6('3ffe:ffff::210:a4ff:fe01:1');
  -> '1.0.0.0.1.0.e.f.f.f.4.a.0.1.2.0.0.0.0.0.0.0.0.0.f.f.f.f.e.f.f.3.ip6.arpa.'
  my $reverseip = GetReverseIPforIPv6('3ffe:ffff::');
  -> '0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.f.f.f.f.e.f.f.3.ip6.arpa.'

=cut

BEGIN{$TYPEINFO{GetReverseIPforIPv6} = ["function","string","string"]};
sub GetReverseIPforIPv6 {
    my $class = shift;
    my $ipv6  = shift || '';

    return undef if (!IP->Check6($ipv6));

    # get full-length IPv6
    $ipv6 = $class->GetFullIPv6 ($ipv6);
    # colons are ignored for reverse IP
    $ipv6 =~ s/://g;

    # all letters one by one
    # in reverse order
    # join with a dot
    # reverse IPv6 suffix at the end
    my $reverseip = join ('.', reverse (split (//, $ipv6))).'.ip6.arpa.';

    return $reverseip;
}

=item *
C<$reverseip = GetCompressedIPv6($ipv6);>

Returns compressed IPv6.

EXAMPLE:

  my $compressed = GetCompressedIPv6('3ffe:ffff:0000:0000:0000:0000:0000:0001');
  -> '3ffe:ffff::1'
  my $compressed = GetCompressedIPv6('3ffe:ffff:0000:0000:0210:a4ff:fe01:0001');
  -> '3ffe:ffff::210:a4ff:fe01:1'
  my $compressed = GetCompressedIPv6('3ffe:ffff:0000:0000:0000:0000:0000:0000');
  -> '3ffe:ffff::'
  my $compressed = GetCompressedIPv6('0000:0025:0000:0000:0000:0000:0000:0000');
  -> '0:25::'
  my $compressed = GetCompressedIPv6('0000:0000:0000:0025:0000:0025:0000:0000');
  -> '::25:0:25:0:0'

=cut

BEGIN{$TYPEINFO{GetCompressedIPv6} = ["function","string","string"]};
sub GetCompressedIPv6 {
    my $class = shift;
    my $ipv6  = shift || '';

    return undef if (!IP->Check6($ipv6));

    my @ipv6parts = split (/:/, $ipv6);
    foreach my $part (@ipv6parts) {
	$part =~ s/^0+//;
	$part = '0' if ($part eq '');
    }

    $ipv6 = join (':', @ipv6parts);

    # both at the begin end and at the end
    if ($ipv6 =~ /^0:0:/ && $ipv6 =~ /:0:0$/) {
	my $at_begin = $ipv6;
	my $at_end = $ipv6;

	# zeros at the begin / at the end
	$at_begin =~ s/^(0(:0)+:).*/$1/;
	$at_end =~ s/.*(:(0:)+0)$/$1/;

	# there are more at the begin
	if (length ($at_begin) > length ($at_end)) {
	    $ipv6 =~ s/^0:(0:)+/::/;
	# otherwise
	} else {
	    $ipv6 =~ s/(:0)+:0$/::/;
	}
    # at the begin
    } elsif ($ipv6 =~ /^0:(0:)+/) {
	$ipv6 =~ s/^0:(0:)+/::/;
    # at the end
    } elsif ($ipv6 =~ /(:0)+:0$/) {
	$ipv6 =~ s/(:0)+:0$/::/;
    # somewhere in the middle
    } else {
	$ipv6 =~ s/:(0:){2,}/::/;
    }

    return $ipv6;
}

=item *
C<$reverseip = AddHost($zone, $hostname, $ipv4);>

Function adds forward and reverse records into the administered zones.
Zones must be both defined and they must be 'master's for the zone.

EXAMPLE:

  $success = AddHost('example.org','dhcp25','192.168.58.25');
  $success = AddHost('example.org','dhcp27.example.org.','192.168.58.27');

=cut

# Adds an A host and its PTR ONLY if reverse zone exists
BEGIN{$TYPEINFO{AddHost} = ["function","boolean","string","string","string"]};
sub AddHost {
    my $class = shift;
    my $zone  = shift || '';
    my $key   = shift || '';
    my $value = shift || '';

    return undef if !Init();

    if (!$value) {
	# TRANSLATORS: Popup error message
	Report->Error(__("Host's IP cannot be empty."));
	return 0;
    }

    my $reversezone = $class->GetReverseZoneNameForIP($value) || '';
    if (!$reversezone) {
	# TRANSLATORS: Popup error message, No reverse zone for %1 record found,
	#   %2 is the hostname, %1 is the IPv4
	Report->Error(sformat(__("There is no reverse zone for %1 administered by your DNS server.
Hostname %2 cannot be added."), $value, $key));
	return 0;
    }

    my $reverseip = $class->GetReverseIPforIPv4($value);

    # hostname MUST be in absolute form (for the reverse zone)
    if ($key !~ /\.$/) {
	$key .= '.'.$zone.'.';
    }
    return 0 if (!$class->AddZoneRR($zone,'A',$key,$value));
    return 0 if (!$class->AddZoneRR($reversezone,'PTR',$reverseip,$key));
    return 1;
}

=item *
C<$boolean = RemoveHost($zone, $hostname, $ipv4);>

Function removes forward and reverse records from the administered zones.
Forward zone must be defined, reverse zone is not needed. Both zones must
be administered by this DNS server ('master's);

EXAMPLE:

  $success = RemoveHost('example.org','dhcp25.example.org.','192.168.58.25');
  $success = RemoveHost('example.org','dhcp27','192.168.58.27');

=cut

# Removes an A host and also its PTR if reverse zone exists
BEGIN{$TYPEINFO{RemoveHost} = ["function","boolean","string","string","string"]};
sub RemoveHost {
    my $class = shift;
    my $zone  = shift || '';
    my $key   = shift || '';
    my $value = shift || '';

    return undef if !Init();

    if (!$value) {
	# TRANSLATORS: Popup error message
	Report->Error(__("Host's IP cannot be empty."));
	return 0;
    }

    my $reversezone = $class->GetReverseZoneNameForIP($value) || '';
    return 0 if (!$class->RemoveZoneRR($zone,'A',$key,$value));
    if ($reversezone) {
	# hostname MUST be in absolute form (in the reverse zone)
	if ($key !~ /\.$/) {
	    $key .= '.'.$zone.'.';
	}
	my $reverseip = $class->GetReverseIPforIPv4($value);
	return 0 if (!$class->RemoveZoneRR($reversezone,'PTR',$reverseip,$key));
    }

    return 1;
}

=item *
C<$reverseip = GetZoneHosts($zone);>

Returns list of Zone Hosts which have the forward and also
the reverse record administered by this DNS server. If zone
is not set, all zones administered by this DNS server would be checked.

EXAMPLE:

  my $hosts = GetZoneHosts();
  foreach my $host (@{$hosts}) {
    print
      "zone: ".$host->{'zone'}." ".
      "hostname: ".$host->{'key'}." ".
      "ipv4: ".$host->{'value'};
  }

=cut

BEGIN{$TYPEINFO{GetZoneHosts} = ["function", ["list", ["map", "string", "string"]], "string"]};
sub GetZoneHosts {
    my $class      = shift;
    my $zone_only  = shift || '';

    return undef if !Init();

    my $zones = $class->GetZones();

    my $ptr_records = {};
    my @types = ('PTR');
    foreach my $zone (keys %{$zones}) {
	next if ($zones->{$zone}->{'type'} ne 'master');
	next if ($zone !~ /\.in-addr\.arpa$/);
	foreach my $record (@{$class->GetZoneRecords($zone, \@types)}) {
	    $record->{'value'} = $class->GetFullHostname($zone, $record->{'value'});
	    $record->{'key'}   = $class->GetFullHostname($zone, $record->{'key'});
	    # hostname/reverse_ip
	    $ptr_records->{$record->{'value'}.'/'.$record->{'key'}} = 1;
	}
    }
    
    my @hosts = ();
    @types = ('A');
    foreach my $zone (keys %{$zones}) {
	next if ($zone_only && $zone_only ne $zone);
	next if ($zones->{$zone}->{'type'} ne 'master');
	next if ($zone =~ /\.in-addr\.arpa$/);
	
	foreach my $record (@{$class->GetZoneRecords($zone, \@types)}) {
	    $record->{'key'}        = $class->GetFullHostname($zone, $record->{'key'});
	    $record->{'value'}      = $class->GetFullHostname($zone, $record->{'value'});
	    $record->{'reverse_ip'} = $class->GetReverseIPforIPv4($record->{'value'});

	    # hostname/reverse_ip
	    if (defined $ptr_records->{$record->{'key'}.'/'.$record->{'reverse_ip'}}) {
		push @hosts, {
		    'zone',    => $zone,
		    'hostname' => $record->{'key'},
		    'ip'       => $record->{'value'}
		};
	    }
	}
    }

    return \@hosts;
}

=item *
C<$array = GetZoneForwarders($string);>

Function returns list of zone forwarders.

EXAMPLE:

    $list_of_forwarders = GetZoneForwarders('example.org');

=cut

BEGIN{$TYPEINFO{GetZoneForwarders} = ["function", ["list", "string"], "string"]};
sub GetZoneForwarders {
    my $class = shift;
    my $zone  = shift || '';

    return undef if !Init();

    return undef if (!$class->CheckZone($zone));

    my @forwarders;
    my $zones = DnsServer->FetchZones();
    foreach my $one_zone (@$zones) {
	if ($zone eq $one_zone->{'zone'}) {
	    @forwarders = GetListFromRecord($one_zone->{'forwarders'});
	    last;
	}
    }

    return \@forwarders;
}

=item *
C<$boolean = SetZoneForwarders($string, $array);>

Function sets forwarders for the zone.

EXAMPLE:

  my @forwarders = SetZoneForwarders('192.168.32.1','192.168.32.2');
  my $zone = 'example.org';
  my $success = SetZoneForwarders($zone, \@masterservers);

=cut

BEGIN{$TYPEINFO{SetZoneForwarders} = ["function", "boolean", "string", ["list", "string"]]};
sub SetZoneForwarders {
    my $class      = shift;
    my $zone       = shift || '';
    my $forwarders = shift;

    return undef if !Init();

    return 0 if (!$class->CheckZone($zone));
    return 0 if (!$class->CheckIPv4s($forwarders));

    my $zones = DnsServer->FetchZones();
    my $zone_counter = 0;
    foreach my $one_zone (@{$zones}) {
	if ($zone eq $one_zone->{'zone'}) {
	    $one_zone->{'forwarders'} = GetRecordFromList(@{$forwarders});
	    $one_zone->{'modified'} = 1;
	    @{$zones}[$zone_counter] = $one_zone;
	    DnsServer->StoreZones($zones);
	    last;
	}
	++$zone_counter;
    }

    return 1;
}

=item *
C<$boolean = ServiceIsConfigurableExternally();>

Checks whether the needed DNS Server package is installed
and whether the server is enabled, or at least, running.

EXAMPLE:

  my $configurable = IsServiceConfigurableExternally()

=cut

BEGIN{$TYPEINFO{IsServiceConfigurableExternally} = ["function", "boolean"]};
sub IsServiceConfigurableExternally {
    my $class = shift;

    return undef if !Init();

    my $service_enabled   = Service->Enabled         ("named");
    my $service_status    = Service->Status          ("named");
    my $service_installed = PackageSystem->Installed ("bind");

    y2milestone (
	"Enabled: ".$service_enabled.", ".
	"Status: ".$service_status.", ".
	"Installed: ".$service_installed
    );
    
    return 0 if ($service_installed != 1);
    return 0 if ($service_enabled != 1 && $service_status != 0);

    return 1;
}

1;
