#!/usr/bin/perl -w
#
# Author: Ladislav Slezák <lslezak@novell.com>
#
# $Id:$
#
# URLRecode.pm
#
# This is a replacement for URI::Encode perl module which cannot be used in inst-sys
# and to decrease the package dependencies
#

package URLRecode;

use strict;
use YaST::YCP qw(:LOGGING Boolean sformat);;

our %TYPEINFO;
use strict;

# local cache for char -> hex string conversion
our %escape_cache;

# fill the cache
sub InitCache
{
    for(0..255) {$escape_cache{chr($_)} = sprintf("%%%02x", $_);}
}


# Escape password, user name and fragment part of URL string
# @param input input string
# @return string Escaped string
BEGIN{ $TYPEINFO{EscapePassword} = ["function", "string", "string"];}
sub EscapePassword
{
    my ($self, $escaped) = @_;

    if (!defined %escape_cache) { InitCache(); }

    $escaped =~ s/([^A-Za-z0-9\\-_.!~*'()])/$escape_cache{$1}/ge;
    return $escaped;
}

# Escape path part of URL string
# @param input input string
# @return string Escaped string
BEGIN{ $TYPEINFO{EscapePath} = ["function", "string", "string"];}
sub EscapePath
{
    my ($self, $escaped) = @_;

    if (!defined %escape_cache) { InitCache() };

    $escaped =~ s/([^A-Za-z0-9\-_.!~*'()\/])/$escape_cache{$1}/ge;
    return $escaped;
}

# Escape query part of URL string
# @param input input string
# @return string Escaped string
BEGIN{ $TYPEINFO{EscapeQuery} = ["function", "string", "string"];}
sub EscapeQuery
{
    my ($self, $escaped) = @_;

    if (!defined %escape_cache) { InitCache(); }

    $escaped =~ s/([^A-Za-z0-9\\-_.!~*'()\/:=&])/$escape_cache{$1}/ge;
    return $escaped;
}


# UnEscape an URL string, replace %<Hexnum><HexNum> sequences
# by character
# @param input input string
# @return string Unescaped string
BEGIN{ $TYPEINFO{UnEscape} = ["function", "string", "string"];}
sub UnEscape
{
    my ($self, $input) = @_;
   
    $input =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
    return $input
}

1;
