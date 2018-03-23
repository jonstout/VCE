#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 19;
use Test::Deep;

use Data::Dumper;
use VCE;
use JSON::XS;
use GRNOC::Log;

my $logger = GRNOC::Log->new( level => 'ERROR');

#remove our temprorary nm file
`cp t/etc/nm2.sqlite.orig t/etc/nm2.sqlite`;

my $vce = VCE->new( config_file => './t/etc/test_config.xml',
                    network_model_file => './t/etc/nm2.sqlite'  );

ok(defined($vce), "VCE object created");

my $vlans = $vce->network_model->get_vlans();

ok($#{$vlans} == -1, "New configuration created!");

my $vlan = $vce->network_model->add_vlan( description => '12-addvlan circuit 1',
                                             workgroup => 'ajco',
                                             username => 'aragusa',
                                             vlan => 101,
                                             switch => 'foobar',
                                             endpoints => [{ port => 'eth0/1'},
                                                           { port => 'eth0/2'}]);

ok(defined($vlan->{vlan_id}), "VLAN was create!");
ok(!defined $vlan->{error}, "VLAN was create! valid error");

my $vlan_id = $vlan->{vlan_id};

my $vlan_details = $vce->network_model->get_vlan_details(vlan_id => $vlan_id);

ok(defined($vlan_details), "VLAN Was found in the configuration");
ok($vlan_details->{'workgroup'} eq 'ajco', "proper workgroup");
ok($vlan_details->{'username'} eq 'aragusa', "proper user");
ok($vlan_details->{'description'} eq '12-addvlan circuit 1');
ok($vlan_details->{'vlan'} == 101, "proper vlan tag");
ok($vlan_details->{'switch'} eq 'foobar', "proper switch");
ok($#{$vlan_details->{'endpoints'}} == 1, "proper number of endpoints");

ok($vlan_details->{'endpoints'}->[0]->{'port'} eq 'eth0/1', "proper port for ep 1");
ok($vlan_details->{'endpoints'}->[1]->{'port'} eq 'eth0/2', "proper port for ep 2");

$vlan = $vce->network_model->add_vlan(
    description => '12-addvlan circuit 2 should fail because vlan_id already there',
    workgroup => 'ajco',
    username => 'aragusa',
    switch => 'foobar',
    vlan => 101,
    vlan_id => $vlan_id,
    endpoints => [
        { switch => 'foobar', port => 'eth0/1', vlan => 102 },
        { switch => 'foobar', port => 'eth0/2', vlan => 102 }
    ]
);

ok(!defined $vlan->{vlan_id}, "VLAN with this ID already exists couldn't add");
ok(defined $vlan->{error}, "VLAN with this ID already exists couldn't add. valid error");
warn Dumper($vlan);

$vlan = $vce->network_model->add_vlan(
    description => '12-addvlan circuit 3 should fail',
    workgroup => 'ajco',
    username => 'aragusa',
    vlan => 101,
    switch => 'foobar',
    endpoints => [
        { port => 'eth0/1' },
        { port => 'eth0/2' }
    ]
);

ok(!defined $vlan->{vlan_id}, "Prevented provisoning of vlan tag already in use");
ok(defined $vlan->{error}, "Prevented provisoning of vlan tag already in use. valid error");

$vlan = $vce->network_model->add_vlan(
    description => '12-addvlan circuit 4 should fail because vlan_id already there',
    workgroup => 'ajco',
    username => 'aragusa',
    switch => 'foobar',
    vlan => 102,
    endpoints => [
        { port => 'eth0/1' },
        { port => 'eth0/2' }
    ]
);
ok(defined $vlan->{vlan_id}, "Was able to create a second vlan with different VLAN IDs");
ok(!defined $vlan->{error}, "Was able to create a second vlan with different VLAN IDs");
