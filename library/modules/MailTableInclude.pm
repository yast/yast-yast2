#!/usr/bin/perl -w
#
# Author: Martin Vidner <mvidner@suse.cz>
# $Id: MailTableInclude.pm 35036 2007-01-02 14:40:18Z mvidner $
# to be included via "do 'MailTableInclude.pm'"


use strict;

# the including file must declare these
our $filename;
our $continue_escaped_newline;
our $continue_leading_blanks;
our $colon;

use Errno qw(ENOENT);
use YaST::YCP qw(:LOGGING);

# Global variables:
# The file specifies a map, but we represent it as a list to preserve
# preceding comments and the order of entries.
# list entries:
#  { "comment" => " foo\n bar\n", "key" => "root", "value" => "joe, \\root" }
#  that is, comments have the leading '#' stripped but not the newline.
# Before the first entry, there can be a leading comment, separated by
# a blank line.
our $leading_comment;
our @table;
our $trailing_comment;

# Parser features:

my $modified = 0;
my $linenum;
my $line_comment;
my $line = "";
my $backslashed_line;

my $separator = $colon ? qr/:\s+/ : qr/\s+/;
my $oseparator = $colon ? ":\t" : "\t";

my $debug = defined($ARGV[0]) && $ARGV[0] eq "-d";

#
# routine to log and return error
#
sub log_error ( $ ) {
    my ($err_msg) = @_;
    y2error ($err_msg);
    return 0;
}

sub dumpit () {
    print STDERR "line: '$line' line_comment: '$line_comment'\n";
}

# create a map entry after it has been composed of split lines
sub parse_line ($)
{
    my $line = shift;

    # is this the first line?
    if ($line ne "")
    {
	if ($line =~ /^(.*?)$separator(.*)$/s)
	{
	    push (@table, { "comment" => $line_comment,
			    "key" => $1,
			    "value" => $2 });
	}
	else
	{
	    log_error ("No separator, $filename:$linenum '$line'");
	}
    }
}

#
sub parse_file ()
{
    $linenum = 0;
    $line = "";
    $line_comment = "";
    $backslashed_line = "";
    my $leading_comment_allowed = 1;

    $leading_comment = "";
    @table = ();
    $trailing_comment = "";

    if (!open (FILE, $filename))
    {
	y2error ("$filename: $!") unless ($! == ENOENT);
	# a missing file will be fixed by the module anyway
	# and y2cc starts all agents :(
	return;
    }

    while (<FILE>)
    {
	chomp; # \n
	++$linenum;
	dumpit () if ($debug);

	# Escaped newlines: merge them before any other processing.
	# Is this one escaped?
	if ($continue_escaped_newline && /\\$/)
	{
	    print STDERR "$linenum:continued\n" if ($debug);
	    chop; # \\
	    $backslashed_line .= "$_ ";
	    next;
	}
	# Was there one already?
	if ($backslashed_line ne "")
	{
	    $_ = $backslashed_line . $_;
	    $backslashed_line = "";
	}


	# Accept comments
	if (/^\#(.*)/)
	{
	    print STDERR "$linenum:comment\n" if ($debug);
	    $trailing_comment .= "$1\n";
	}
	elsif (/^$/)
	{
	    if ($leading_comment_allowed)
	    {
		$leading_comment .= $trailing_comment;
		$trailing_comment = "";
	    }
	}
	else
	{
	    $leading_comment_allowed = 0;
	    # $line is the previous line, $_ is the current one
	    if (/^\s+(.*)/)
	    {
		if ($continue_leading_blanks)
		{
		    print STDERR "$linenum:leading blanks\n" if ($debug);
		    $line .= $_;
		    $line_comment .= $trailing_comment;
		    $trailing_comment = "";
		}
		else
		{
		    log_error ("Leading whitespace, $filename:$linenum");
		}
	    }
	    else
	    {
		    print STDERR "$linenum:regular\n" if ($debug);
		    # a regular line. process the _previous_ one
		    # because this one might continue

		    parse_line ($line);

		    # next buffer
		    $line = $_;
		    $line_comment = $trailing_comment;
		    $trailing_comment = "";
	    }
	}
    }
    # end of file, but we must not forget to process the buffer!
    parse_line ($line);
    # only a comment: make it a leading one
    if ($leading_comment_allowed)
    {
	$leading_comment .= $trailing_comment;
	$trailing_comment = "";
    }

    close (FILE);
}

# take a multiline string and write it to FILE with a hash before each line
sub write_comment ($)
{
    my $comment = shift;
    foreach my $line (split /\n/, $comment || "")
    {
	print FILE "\#$line\n";
    }
}
#
sub write_file ()
{
    return 1 if (! $modified);

    open (FILE, ">$filename.YaST2.new") or return log_error ("Creating file: $!");
    if ($leading_comment)
    {
	write_comment ($leading_comment);
	print FILE "\n";
    }
    foreach my $entry (@table)
    {
	write_comment ($entry->{"comment"});
	print FILE $entry->{"key"}, $oseparator, $entry->{"value"}, "\n";
    }
    write_comment ($trailing_comment);
    close (FILE);

    if (-f $filename)
    {
	rename $filename, "$filename.YaST2save" or return log_error ("Creating backup: $!");
    }
    rename "$filename.YaST2.new", $filename or return log_error ("Moving temp file: $!");

    $modified = 0;
    return 1;
}

# interface with MailTable.pm

sub Read ()
{
    parse_file ();
    $modified = 0;

    return \@table;
}

sub Write ()
{
    my $value = shift;
    @table = @{$value};
    $modified = 1;
    return 1;
}

sub Flush ()
{
    return write_file();
}
