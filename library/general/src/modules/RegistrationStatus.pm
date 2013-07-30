#
# Copyright (c) 2011 Novell, Inc.
# 
# All Rights Reserved.
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
# 
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#

package RegistrationStatus;

use strict;
use Data::Dumper;
use XML::Simple;
use XML::XPath;
use POSIX qw/strftime/;

use YaST::YCP qw(:DATA :LOGGING);

our %TYPEINFO;

# see https://wiki.innerweb.novell.com/index.php/Registration#Add_Registration_Status_to_zmdconfig
# for more datils about the file format
my $reg_file = "/var/lib/suseRegister/registration-status.xml";

my $productsd = "/etc/products.d";

# return the default registration status file name
BEGIN{ $TYPEINFO{RegFile} = ["function", "string"]; }
sub RegFile {
    my ($self) = @_;
    return $reg_file;
}

# parse the default registration XML status file
BEGIN{ $TYPEINFO{Read} = ["function", ["map","any","any"]]; }
sub Read {
    my ($self) = @_;
    return ReadFile($reg_file);
}

# parse the requested registration XML status file, convert the XML file into a map
BEGIN{ $TYPEINFO{ReadFile} = ["function", ["map","any","any"], "string"]; }
sub ReadFile {
    my $self = shift;
    my $file = shift;

    # create XML parser
    my $parser = new XML::Simple;

    # parse the file
    my $data = $parser->XMLin($file);

    my $dump = Dumper($data);
    y2milestone("Parsed file $file: $dump");

    return $data;
}

# parse registration-status.xml with XML::XPath (more solid and more predictable output than XML-Simple)
BEGIN{ $TYPEINFO{ParseStatusXML} = ["function", ["map","any","any"], "string"]; }
sub ParseStatusXML() {
    my $self = shift;
    my $file = shift || $reg_file;
    my $status = {};

    if ( ! -s $file || -d $file ) {
        y2milestone("Missing or empty registration-status xml file: $file");
        return { __parser_status => 10, __parser_message => "File missing or empty: $file" };
    }

    my $xp = XML::XPath->new(filename => $file);

    my ($stSet, $st);
    eval { $stSet = $xp->find('/status[1]') };

    if ( $@ || ! ((defined $stSet) && ($stSet->size() == 1)) ) {
        y2error("Could not parse the registration-status xml file: $file");
        return { __parser_status => 11, __parser_message => "Could not parse status file." };
    }
    else {
        y2milestone("Found status information in the registration-status xml file: $file");
        $st = $stSet->pop();
    }

    $status->{generated} = $st->getAttribute('generated') || 0;
    $status->{_generated_fmt} = strftime("%Y-%m-%d %H:%M:%S", localtime($status->{generated}));

    my ($psSet, $ps);
    eval { $psSet = $xp->find('/status[1]/productstatus') };
    if ( $@ || ! ((defined $psSet) && ($psSet->size() > 0)) ) {
      y2error("The status file ($file) does not contain productstatus information.");
      return {__parser_status => 12, __parser_message => "No productstatus information found." };
    }

    $status->{__parser_status} = 0;

    foreach my $n ($psSet->get_nodelist()) {
        next unless defined $n;
        my ($_product,$_version,$_arch,$_release,$_messageSet,$_message,$_subscriptionSet,$_subscription);
        $_product = $n->getAttribute('product') || '';
        $_version = $n->getAttribute('version') || '';
        $_arch    = $n->getAttribute('arch')    || '';
        $_release = $n->getAttribute('release') || '';
        my $id_string = $_product.'-'.$_version.'-'.$_arch.'-'.$_release;
        y2milestone("Processing product status for: $id_string");

        eval { $_messageSet = $n->findnodes("message[1]") };
        if ($@) {
            y2error("Error while parsing the messasge of a product status.");
        } else {
            foreach my $_node ($_messageSet->get_nodelist()) {
                $_message = $_node->string_value() if (defined $_node);
            }
        }
        $_message ||= '';

        eval { $_subscriptionSet = $n->findnodes("subscription[1]")};
        if ( $@ || ! ((defined $_subscriptionSet) && ($_subscriptionSet->size() == 1)) ) {
            y2milestone("The product '$_product' does not have a subscription. It may be fine though.");
            $_subscription = undef;
        } else {
            my $s;
            $s = $_subscriptionSet->pop();
            $_subscription = {
                status     => $s->getAttribute('status')     || '',
                type       => $s->getAttribute('type')       || '',
                expiration => $s->getAttribute('expiration') || ''
            };
            $_subscription->{_expiration_fmt} = ($_subscription->{expiration} =~ /^\d+$/) ?
                strftime("%Y-%m-%d %H:%M:%S", localtime($_subscription->{expiration})) : '';
        }

        my $_prodinfo;
        my @prodvals = qw(summary shortsummary vendor name version baseversion patchlevel release arch productline);
        my $prodfile = "$productsd/$_product.prod";
        if ( -f "$prodfile" && -s "$prodfile" ) {
            my ($pxml, $pxmlparser, $pxmltree);
            if ( open(PROD, "<", "$prodfile") ) {
                $pxml = do { local $/; <PROD> };
                close PROD;
                $pxmlparser = XML::XPath::XMLParser->new(xml => $pxml);
                eval { $pxmltree = $pxmlparser->parse(); };
                if ($@) {
                    y2error("Error: Could not parse the products file for the product: $_product");
                } else {
                    foreach my $val (@prodvals) {
                        my ($valn, $valSet);
                        eval { $valSet = $xp->findnodes("/product/$val", $pxmltree); };
                        next unless ( (defined $valSet) && ($valSet->size() > 0) );
                        $valn = $valSet->pop();
                        $_prodinfo->{$val} = $valn->string_value() if (defined $valn);
                    }
                }
            } else {
                y2milestone("Product file for product $_product could not be opened.");
            }
        } else {
            y2milestone("No product file for product $_product could be found.");
        }

        $status->{products}->{$id_string} = {
            product   => $_product,
            version   => $_version,
            arch      => $_arch,
            release   => $_release,
            result    => $n->getAttribute('result')    || '',
            errorcode => $n->getAttribute('errorcode') || '',
            message   => $_message,
        };
        $status->{products}->{$id_string}->{subscription} = $_subscription if defined $_subscription;
        $status->{products}->{$id_string}->{_productinfo} = $_prodinfo if defined $_prodinfo;
    }

    return $status;
}


1

