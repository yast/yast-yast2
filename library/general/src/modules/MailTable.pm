#!/usr/bin/perl -w
#
# Author: Martin Vidner <mvidner@suse.cz>
# $Id: MailTable.pm 35039 2007-01-03 12:39:54Z mvidner $
#
#  Accessing sendmail and postfix maps described in
#  makemap(8) and postmap(1)

use strict;

package MailTable;
use YaST::YCP qw(:LOGGING);

# type information for YCP
our %TYPEINFO;

my %modules =
    (
     "aliases" => "Aliases",
     "postfix.sendercanonical" => "PostfixSenderCanonical",
     "postfix.virtual" => "PostfixVirtual",
     "sendmail.generics" => "SendmailGenerics",
     "sendmail.virtuser" => "SendmailVirtuser",
    );

BEGIN {$TYPEINFO{Read} = ["function", ["list", ["map", "string", "any"]], "string kind"];}
sub Read
{
    my $class = shift;
    my $kind = shift;

    if (!exists $modules{$kind}) {
	y2internal ("No module defined for $kind");
	return [];
    }
    no strict "refs";
    return &{"MailTable::$modules{$kind}::Read"}();
}


BEGIN {$TYPEINFO{Write} = ["function", "boolean", "string kind", ["list", ["map", "any", "any"]]];}
sub Write
{
    my $class = shift;
    my $kind = shift;
    my $value = shift;

    if (!exists $modules{$kind}) {
	y2internal ("No module defined for $kind");
	return 0;
    }
    no strict "refs";
    return &{"MailTable::$modules{$kind}::Write"}($value);
}

BEGIN {$TYPEINFO{Flush} = ["function", "boolean", "string kind"];}
sub Flush
{
    my $class = shift;
    my $kind = shift;

    if (!exists $modules{$kind}) {
	y2internal ("No module defined for $kind");
	return 0;
    }
    no strict "refs";
    return &{"MailTable::$modules{$kind}::Flush"}();
}

BEGIN {$TYPEINFO{FileName} = ["function", "string", "string kind"];}
sub FileName
{
    my $class = shift;
    my $kind = shift;

    if (!exists $modules{$kind}) {
	y2internal ("No module defined for $kind");
	return "FIXME $kind";
    }
    no strict "refs";
    return ${"MailTable::$modules{$kind}::filename"};
}

# For testing purposes only
# Sets filename, returns previous one
BEGIN {$TYPEINFO{SetFileName} = ["function", "string", "string kind", "string new"];}
sub SetFileName
{
    my $class = shift;
    my $kind = shift;
    my $new = shift;

    if (!exists $modules{$kind}) {
	y2internal ("No module defined for $kind");
	return "FIXME $kind";
    }
    no strict "refs";
    my $fn_ref = "MailTable::$modules{$kind}::filename";
    my $old = ${$fn_ref};
    ${$fn_ref} = $new;
    return $old;
}

package MailTable::Aliases;

our $filename = "/etc/aliases";
our $continue_escaped_newline = 1;
our $continue_leading_blanks = 1;
our $colon = 1;

do 'MailTableInclude.pm';

package MailTable::PostfixSenderCanonical;

our $filename = "/etc/postfix/sender_canonical";
our $continue_escaped_newline = 0;
our $continue_leading_blanks = 1;
our $colon = 0;

do 'MailTableInclude.pm';

package MailTable::PostfixVirtual;

our $filename = "/etc/postfix/virtual";
our $continue_escaped_newline = 0;
our $continue_leading_blanks = 1;
our $colon = 0;

do 'MailTableInclude.pm';

package MailTable::SendmailGenerics;

our $filename = "/etc/mail/genericstable";
our $continue_escaped_newline = 0;
our $continue_leading_blanks = 0;
our $colon = 0;

do 'MailTableInclude.pm';

package MailTable::SendmailVirtuser;

our $filename = "/etc/mail/virtusertable";
our $continue_escaped_newline = 0;
our $continue_leading_blanks = 0;
our $colon = 0;

do 'MailTableInclude.pm';

1;
