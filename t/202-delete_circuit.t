#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 30;
use Test::Deep;
use GRNOC::WebService::Client;
use Data::Dumper;

`cp t/etc/nm1.json.orig t/etc/nm1.json`;

my $client = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                             realm => 'VCE',
                                             uid => 'aragusa',
                                             passwd => 'unittester',
                                             debug => 0,
                                             timeout => 60 );

my $provisioner = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/provisioning.cgi',
                                                  realm => 'VCE',
                                                  uid => 'aragusa',
                                                  passwd => 'unittester',
                                                  debug => 0,
                                                  timeout => 60 );

my $vlans = $client->get_vlans( workgroup => 'ajco' );

ok(defined($vlans), "Got a response");
ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 1, "Expected circuits found!");

my $vlan = $provisioner->add_vlan( description => "Automated test suite!",
                                    switch => ['foobar','foobar'],
                                    port => ['eth0/1','eth0/2'],
                                    tag => ['104','104'],
                                    workgroup => 'ajco');

ok(defined($vlan), "got a response");
ok($vlan->{'results'}->[0]->{'success'} == 1, "Success provisioning!");
ok(defined($vlan->{'results'}->[0]->{'vlan_id'}), "Got a VLAN ID Back!");

$vlans = $client->get_vlans( workgroup => 'ajco');

ok(defined($vlans), "Got a valid response");
ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 2, "We now see that we have a VLAN!");

my $vlan_details = $client->get_vlan_details( vlan_id => $vlan->{'results'}->[0]->{'vlan_id'},
                                              workgroup => 'ajco');

ok(defined($vlan_details), "Got vlan details response");

delete $vlan_details->{'results'}->[0]->{'circuit'}->{'create_time'};
delete $vlan_details->{'results'}->[0]->{'circuit'}->{'vlan_id'};

cmp_deeply($vlan_details,{
    'results' => [
        {
            'circuit' => {
                'workgroup' => 'ajco',
                'status' => 'Active',
                'description' => 'Automated test suite!',
                'endpoints' => [
                    {
                        'switch' => 'foobar',
                        'tag' => '104',
                        'port' => 'eth0/1'
                    },
                    {
                        'switch' => 'foobar',
                        'tag' => '104',
                        'port' => 'eth0/2'
                    }
                    ],
                'username' => 'aragusa'
            }
        }
        ]
           });

my $delete = $provisioner->delete_vlan( vlan_id => $vlan->{'results'}->[0]->{'vlan_id'},
                                        workgroup => 'ajco');

ok($delete->{'results'}->[0]->{'success'} == 1, "Successfully delete the circuit");

$vlans = $client->get_vlans( workgroup => 'ajco');

ok(defined($vlans), "Got a valid response");
ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 1, "Looks like we successfully deleted it");

$vlan = $provisioner->add_vlan( description => "Automated test suite!",
                                switch => ['foobar','foobar'],
                                port => ['eth0/1','eth0/2'],
                                tag => ['104','104'],
                                workgroup => 'ajco');

ok(defined($vlan), "got a response");
ok($vlan->{'results'}->[0]->{'success'} == 1, "Success provisioning!");
ok(defined($vlan->{'results'}->[0]->{'vlan_id'}), "Got a VLAN ID Back!");

$vlans = $client->get_vlans( workgroup => 'ajco');

ok(defined($vlans), "Got a valid response");
ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 2, "We now see that we have a VLAN!");

$vlan_details = $client->get_vlan_details( vlan_id => $vlan->{'results'}->[0]->{'vlan_id'},
                                           workgroup => 'ajco');

ok(defined($vlan_details), "Got vlan details response");

delete $vlan_details->{'results'}->[0]->{'circuit'}->{'create_time'};
delete $vlan_details->{'results'}->[0]->{'circuit'}->{'vlan_id'};

cmp_deeply($vlan_details,{
    'results' => [
        {
            'circuit' => {
                'workgroup' => 'ajco',
                'status' => 'Active',
                'description' => 'Automated test suite!',
                'endpoints' => [
                    {
                        'switch' => 'foobar',
                        'tag' => '104',
                        'port' => 'eth0/1'
                    },
                    {
                        'switch' => 'foobar',
                        'tag' => '104',
                        'port' => 'eth0/2'
                    }
                    ],
                'username' => 'aragusa'
            }
        }
        ]
           });

$delete = $provisioner->delete_vlan( vlan_id => $vlan->{'results'}->[0]->{'vlan_id'},
                                     workgroup => 'edco');

ok($delete->{'results'}->[0]->{'success'} == 0, "Unable to delete the circuit");
ok($delete->{'error'}->{'msg'} eq 'User aragusa not in specified workgroup edco', "User not in workgroup error");
$vlans = $client->get_vlans( workgroup => 'ajco');

ok(defined($vlans), "Got a valid response");
ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 2, "Looks like we did not successfully delete it");

my $provisioner2 = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/provisioning.cgi',
                                                   realm => 'VCE',
                                                   uid => 'ebalas',
                                                   passwd => 'unittester',
                                                   debug => 0,
                                                   timeout => 60 );

$delete = $provisioner2->delete_vlan( vlan_id => $vlan->{'results'}->[0]->{'vlan_id'},
                                      workgroup => 'edco');

ok($delete->{'results'}->[0]->{'success'} == 0, "Unable to delete the circuit");
ok($delete->{'error'}->{'msg'} =~ /Workgroup edco is not allowed to edit vlan/, "Proper error when not correct workgroup");
$vlans = $client->get_vlans( workgroup => 'ajco');

ok(defined($vlans), "Got a valid response");
ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 2, "Looks like we did not successfully delete it");

$delete = $provisioner->delete_vlan( vlan_id => '11111',
                                     workgroup => 'ajco');

warn Dumper($delete);
ok($delete->{'results'}->[0] == {}, "Unable to delete the circuit");

$vlans = $client->get_vlans( workgroup => 'ajco');

ok(defined($vlans), "Got a valid response");
ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 2, "Looks like we did not successfully delete it");
