#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 9;

use GRNOC::WebService::Client;
use Data::Dumper;

my $client = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                             realm => 'VCE',
                                             uid => 'aragusa',
                                             passwd => 'unittester',
                                             debug => 0,
                                             timeout => 60 );

my $vlans = $client->get_vlans( workgroup => 'ajco' );
                                

ok(defined($vlans), "vlans result was defined for AJ");
ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 1, "Proper number of vlans returned");
ok($vlans->{'results'}->[0]->{'vlans'}->[0] eq '979f9708-7102-4762-8a6a-8e30ed80b88c', "First vlan returned properly");
ok($vlans->{'results'}->[0]->{'vlans'}->[1] eq 'b0c0103e-b2dc-47cd-a687-c73dd9100fd2', "Second vlan returned properly");

$vlans = $client->get_vlans( workgroup => 'edco' );
ok(defined($vlans->{'error'}) && $vlans->{'error'}->{'msg'} eq 'User aragusa not in specified workgroup edco');

$vlans = $client->get_vlans( workgroup => 'foobar' );
ok(defined($vlans->{'error'}) && $vlans->{'error'}->{'msg'} eq 'User aragusa not in specified workgroup foobar');

my $client2 = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                           realm => 'VCE',
                                           uid => 'ebalas',
                                           passwd => 'unittester',
                                           debug => 0,
                                           timeout => 60 );

$vlans = $client2->get_vlans( workgroup => 'edco');

ok(defined($vlans), "Got a valid response");

ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 0, "Got the proper number of VLANs back");

ok($vlans->{'results'}->[0]->{'vlans'}->[0] eq '2806baa4-173c-4bdd-b552-c063a82e232f', "Got the proper vlan ID back");
