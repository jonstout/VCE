#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 12;

use GRNOC::WebService::Client;
use Data::Dumper;

`cp ./t/etc/nm1.json.orig ./t/etc/nm1.json`;

my $client = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                             realm => 'VCE',
                                             uid => 'aragusa',
                                             passwd => 'unittester',
                                             debug => 0,
                                             timeout => 60 );

my $vlans = $client->get_vlans( workgroup => 'ajco' );
                                

ok(defined($vlans), "vlans result was defined for AJ");

ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 2, "Proper number of vlans returned");
ok($vlans->{'results'}->[0]->{'vlans'}->[0]->{'vlan_id'} eq '979f9708-7102-4762-8a6a-8e30ed80b88c', "First vlan returned properly");
# eth0/2 is owned by ajco; This means all VLANs that use this port must be returned by GET VLANs.
ok($vlans->{'results'}->[0]->{'vlans'}->[1]->{'vlan_id'} eq '2806baa4-173c-4bdd-b552-c063a82e232f', "Second vlan returned properly");
ok($vlans->{'results'}->[0]->{'vlans'}->[2]->{'vlan_id'} eq 'b0c0103e-b2dc-47cd-a687-c73dd9100fd2', "Third vlan returned properly");

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

ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 2, "Got the proper number of VLANs back");
# eth0/1 is owned by edco; This means all VLANs that use this port must be returned by GET VLANs.
ok($vlans->{'results'}->[0]->{'vlans'}->[0]->{'vlan_id'} eq '979f9708-7102-4762-8a6a-8e30ed80b88c', "First vlan returned properly");
ok($vlans->{'results'}->[0]->{'vlans'}->[1]->{'vlan_id'} eq '2806baa4-173c-4bdd-b552-c063a82e232f', "Second vlan returned properly");
# eth0/1 is owned by edco; This means all VLANs that use this port must be returned by GET VLANs.
ok($vlans->{'results'}->[0]->{'vlans'}->[2]->{'vlan_id'} eq 'b0c0103e-b2dc-47cd-a687-c73dd9100fd2', "Third vlan returned properly");
