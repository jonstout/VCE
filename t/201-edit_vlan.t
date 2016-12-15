#!/usr/bin/perl

use strict;
use warnings;
#use Test::More skip_all => "Busted";

use Test::More tests => 28;
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
                                   switch => 'foobar',
                                   port => ['eth0/1','eth0/2'],
                                   vlan => '104',
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
                'switch' => 'foobar',
                'vlan' => '104',
                'endpoints' => [
                    {
                        'port' => 'eth0/1'
                    },
                    {
                        'port' => 'eth0/2'
                    }
                    ],
                'username' => 'aragusa'
            }
        }
        ]
           });

my $edit_vlan = $provisioner->edit_vlan( description => "Automated test suite!",
                                         vlan_id => $vlan->{'results'}->[0]->{'vlan_id'},
                                         switch => 'foobar',
                                         port => ['eth0/1','eth0/2'],
                                         vlan => '105',
                                         workgroup => 'ajco');

ok(defined($edit_vlan), "got a response");
ok($edit_vlan->{'results'}->[0]->{'success'} == 1, "Success provisioning!");
ok(defined($edit_vlan->{'results'}->[0]->{'vlan_id'}), "Got a VLAN ID Back!");

$vlan_details = $client->get_vlan_details( vlan_id => $edit_vlan->{'results'}->[0]->{'vlan_id'},
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
                'switch' => 'foobar',
                'vlan' => '105',
                'endpoints' => [
                    {
                        'port' => 'eth0/1'
                    },
                    {
                        'port' => 'eth0/2'
                    }
                    ],
                'username' => 'aragusa'
            }
        }
        ]
           });


my $new_vlan = $provisioner->add_vlan( description => "Automated test suite!",
                                switch => 'foobar',
                                port => ['eth0/1','eth0/2'],
                                vlan => '104',
                                workgroup => 'ajco');

ok(defined($new_vlan), "got a response");
ok($new_vlan->{'results'}->[0]->{'success'} == 1, "Success provisioning!");
ok(defined($new_vlan->{'results'}->[0]->{'vlan_id'}), "Got a VLAN ID Back!");

$vlans = $client->get_vlans( workgroup => 'ajco');

ok(defined($vlans), "Got a valid response");
ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 3, "We now see that we have anoterh VLAN!");

my $edit_vlan2 = $provisioner->edit_vlan( description => "Automated test suite!",
                                          vlan_id => $vlan->{'results'}->[0]->{'vlan_id'},
                                          switch => 'foobar',
                                          port => ['eth0/1','eth0/2'],
                                          vlan => '104',
                                          workgroup => 'ajco');

ok(defined($edit_vlan2), "Got a response");
ok($edit_vlan2->{'results'}->[0]->{'success'} == 0, "Failed to edit circuit");
ok($edit_vlan2->{'error'}->{'msg'} eq "Circuit does not validate", "proper error when failed to edit circuit");

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
                'switch' => 'foobar',
                'vlan' => '105',
                'endpoints' => [
                    {
                        'port' => 'eth0/1'
                    },
                    {
                        'port' => 'eth0/2'
                    }
                    ],
                'username' => 'aragusa'
            }
        }
        ]
           });

my $edit_vlan3 = $provisioner->edit_vlan( description => "Automated test suite!",
                                          vlan_id => $vlan->{'results'}->[0]->{'vlan_id'},
                                          switch => 'foobar',
                                          port => ['eth0/1','eth0/2'],
                                          vlan => '104',
                                          workgroup => 'edco');

ok(defined($edit_vlan3), "Got a valid response");
ok(defined($edit_vlan3->{'error'}) && $edit_vlan3->{'error'}->{'msg'} eq 'User aragusa not in specified workgroup edco', "Proper error when user not in workgroup");

my $provisioner2 = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/provisioning.cgi',
                                                   realm => 'VCE',
                                                   uid => 'ebalas',
                                                   passwd => 'unittester',
                                                   debug => 0,
                                                   timeout => 60 );


my $edit_vlan4 = $provisioner2->edit_vlan( description => "Automated test suite!",
                                           vlan_id => $vlan->{'results'}->[0]->{'vlan_id'},
                                           switch => 'foobar',
                                           port => ['eth0/1','eth0/2'],
                                           vlan => '99',
                                           workgroup => 'edco');

ok(defined($edit_vlan4), "Got a valid response");
ok($edit_vlan4->{'error'}->{'msg'} =~ /Workgroup edco is not allowed to edit vlan/, "Proper error message when unable to provision");
