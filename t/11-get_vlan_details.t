#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 16;
use Test::Deep;

use VCE;
use GRNOC::Log;

`cp t/etc/nm1.json.orig t/etc/nm1.json`;

my $logger = GRNOC::Log->new( level => 'ERROR');

my $vce = VCE->new( config_file => './t/etc/test_config.xml',
                    network_model_file => './t/etc/nm1.json'  );

ok(defined($vce), "VCE object created");

my $details = $vce->network_model->get_vlan_details( vlan_id => '979f9708-7102-4762-8a6a-8e30ed80b88c');

ok(defined($details), "returned circuit");
ok($details->{'workgroup'} eq 'ajco', "proper workgroup");
ok($details->{'description'} eq 'test', "proper description");
ok($#{$details->{'endpoints'}} == 1, "proper number of endpoints");
ok($details->{'endpoints'}->[0]->{'switch'} eq 'foobar', "proper endpoint 1 switch");
ok($details->{'endpoints'}->[0]->{'port'} eq 'eth0/1', "proper endpoint 1 port");
ok($details->{'endpoints'}->[0]->{'tag'} eq '102', "proper endpoint 1 tag");
ok($details->{'endpoints'}->[1]->{'switch'} eq 'foobar', "proper endpoint 2 switch");
ok($details->{'endpoints'}->[1]->{'port'} eq 'eth0/2', "proper endpoint 2 port");
ok($details->{'endpoints'}->[1]->{'tag'} eq '102', "proper endpoint 2 tag");
ok($details->{'create_time'} eq '1479158369', "proper create time specified");

$details = $vce->network_model->get_vlan_details( vlan_id => 'b0c0103e-b2dc-47cd-a687-c73dd9100fd2');

ok(defined($details), "returned circuit");

$details = $vce->network_model->get_vlan_details( vlan_id => '2806baa4-173c-4bdd-b552-c063a82e232f');

ok(defined($details), "returned circuit");

$details = $vce->network_model->get_vlan_details( vlan_id => '2806baa4-173c-4bdd-b552-c063a82e2323');

ok(!defined($details), "no result when non-existing vlan queried");

$details = $vce->network_model->get_vlan_details( );

ok(!defined($details), "no result when non-existing vlan queried");

