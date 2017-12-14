#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 10;
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

my $vlan = $client->get_vlan_details( workgroup => 'ajco',
                                       vlan_id => '979f9708-7102-4762-8a6a-8e30ed80b88c');

ok(defined($vlan), "vlan result was defined for AJ");

cmp_deeply($vlan->{results}->[0], {
    'circuit' => {
        'workgroup' => 'ajco',
        'status' => 'Active',
        'create_time' => 1479158369,
        'description' => 'test',
        'switch' => 'foobar',
        'vlan' => '102',
        'endpoints' => [
            {
                'switch' => 'foobar',
                'tag' => '102',
                'port' => 'eth0/1'
            },
            {
                'switch' => 'foobar',
                'tag' => '102',
                'port' => 'eth0/2'
            }
        ],
        'username' => 'aragusa',
        'vlan_id' => '979f9708-7102-4762-8a6a-8e30ed80b88c'
    }
});

$vlan = $client->get_vlan_details( workgroup => 'ajco',
                                   vlan_id => 'b0c0103e-b2dc-47cd-a687-c73dd9100fd2');

ok(defined($vlan), "vlan result was defined for AJ");

cmp_deeply($vlan, {
    'results' => [
        {
            'circuit' => {
                'workgroup' => 'ajco',
                'status' => 'Active',
                'create_time' => 1479153788,
                'description' => 'test',
                'switch' => 'foobar',
                'vlan' => 101,
                'endpoints' => [
                    {
                        'switch' => 'foobar',
                        'tag' => '101',
                        'port' => 'eth0/1'
                    },
                    {
                        'switch' => 'foobar',
                        'tag' => '101',
                        'port' => 'eth0/2'
                    }
                    ],
                'username' => 'aragusa',
                'vlan_id' => 'b0c0103e-b2dc-47cd-a687-c73dd9100fd2'
            }
        }
        ]
           }
    );


$vlan = $client->get_vlan_details( workgroup => 'ajco',
                                   vlan_id => '2806baa4-173c-4bdd-b552-c063a82e232f');

ok(defined($vlan), "vlan result was defined for AJ");
ok($vlan->{results}->[0]->{circuit}->{workgroup} eq 'edco', 'Got VLAN because of workgroup owned port.');

my $client2 = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                              realm => 'VCE',
                                              uid => 'ebalas',
                                              passwd => 'unittester',
                                              debug => 0,
                                              timeout => 60 );

$vlan = $client2->get_vlan_details( workgroup => 'edco',
                                    vlan_id => '2806baa4-173c-4bdd-b552-c063a82e232f' );

ok(defined($vlan), "vlan result was defined for Ed");

cmp_deeply($vlan, {
    'results' => [
        {
            'circuit' => {
                'workgroup' => 'edco',
                'status' => 'Active',
                'create_time' => 1479158359,
                'description' => 'test',
                'vlan_id' => '2806baa4-173c-4bdd-b552-c063a82e232f',
                'vlan' => 10,
                'switch' => 'foobar',
                'username' => 'aragusa',
                'endpoints' => [
                    {
                        'switch' => 'foobar',
                        'tag' => '10',
                        'port' => 'eth0/1'
                    },
                    {
                        'switch' => 'foobar',
                        'tag' => '10',
                        'port' => 'eth0/2'
                    }
                    ]
            }
        }
        ]
           });


$vlan = $client->get_vlan_details( workgroup => 'edco',
                                   vlan_id => '2806baa4-173c-4bdd-b552-c063a82e232f');

ok(defined($vlan), "Got a proper response");

ok($vlan->{'error'}->{'msg'} eq "User aragusa not in specified workgroup edco");
