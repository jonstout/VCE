#!/usr/bin/perl

use strict;
use warnings;

use Test::More skip_all => "Busted";
#use Test::More tests => 19;
use Test::Deep;
use GRNOC::WebService::Client;

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

$vlan = $provisioner->add_vlan( description => "Automated test suite!",
                                switch => ['foobar','foobar'],
                                port => ['eth0/1','eth0/2'],
                                tag => ['104','104'],
                                workgroup => 'ajco');

ok(defined($vlan), "Results was returned even though provisioning failed");
ok($vlan->{'results'}->[0]->{'success'} == 0, "Unable to provision because tags already in use!");
ok($vlan->{'error'}->{'msg'} eq 'Unable to add circuit to network model', "Returned an error message saying why we couldn't provision");

$vlan = $provisioner->add_vlan( description => "Automated test suite!",
                                switch => ['foobar','foobar'],
                                port => ['eth0/1','eth0/2'],
                                tag => ['99','110'],
                                workgroup => 'ajco');

ok(defined($vlan), "Results was returned even though provisioning failed");
ok($vlan->{'results'}->[0]->{'success'} == 0, "Unable to provision because tags already in use!");
ok($vlan->{'error'}->{'msg'} eq 'Unable to add circuit to network model', "Returned an error message saying why we couldn't provision");

$vlans = $client->get_vlans( workgroup => 'ajco');
ok(defined($vlans), "Got a valid response");
ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 2, "Making sure we have the right number of circuits still");


$vlan = $provisioner->add_vlan( description => "Automated test suite!",
                                switch => ['foobar','foobar'],
                                port => ['eth0/1','eth0/2'],
                                tag => ['99','99'],
                                workgroup => 'edco');

ok(defined($vlan), "Got a valid response");
ok(defined($vlan->{'error'}) && $vlan->{'error'}->{'msg'} eq 'User aragusa not in specified workgroup edco');
