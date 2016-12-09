#!/usr/bin/perl

use strict;
use warnings;

use Test::More skip_all => "Skipping";

use Test::More tests => 1;

use GRNOC::WebService::Client;
use Data::Dumper;

my $client = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/switch.cgi',
                                             realm => 'VCE',
                                             uid => 'aragusa',
                                             passwd => 'unittester',
                                             debug => 0,
                                             timeout => 60 );

my $interfaces = $client->get_interfaces();

ok(defined($interfaces), "Got a valid response");
