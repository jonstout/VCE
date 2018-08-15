#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 13;
use Test::Deep;

use VCE;
use JSON::XS;
use GRNOC::Log;


my $logger = GRNOC::Log->new( level => 'ERROR');

`cp t/etc/nm3.sqlite.orig2 t/etc/nm3.sqlite`;

my $vce = VCE->new( config_file => './t/etc/test_config.xml',
                    db =>'./t/etc/nm3.sqlite',
                    network_model_file => './t/etc/nm3.sqlite'  );

ok(defined($vce), "VCE object created");

my $vlans = $vce->network_model->get_vlans();

ok($#{$vlans} == -1, "New configuration created!");

my $vlan = $vce->network_model->add_vlan(
    description => '13-delete_vlan circuit 1',
    workgroup => 'ajco',
    username => 'aragusa',
    switch => 'foobar',
    vlan => 101,
    endpoints => [
        { port => 'eth0/1'},
        { port => 'eth0/2'}
    ]
);

my $vlan_id = $vlan->{vlan_id};
ok(defined($vlan_id), "VLAN was create!");

my $vlan_details = $vce->network_model->get_vlan_details(vlan_id => $vlan_id);

ok(defined($vlan_details), "VLAN Was found in the configuration");

$vlans = $vce->network_model->get_vlans();
ok(@{$vlans} == 1, "JSON has proper number of vlans");

$vlan = $vce->network_model->add_vlan(
    description => '12-delete_vlan circuit 2',
    workgroup => 'ajco',
    username => 'aragusa',
    switch => 'foobar',
    vlan => 102,
    endpoints => [
        { port => 'eth0/1'},
        { port => 'eth0/2'}
    ]
);

$vlan_id = $vlan->{vlan_id};
ok(defined($vlan_id), "Second circuit created!");

$vlans = $vce->network_model->get_vlans();
ok(@{$vlans} == 2, "JSON has proper number of vlans");

#ok delete the second only
my $res = $vce->network_model->delete_vlan( vlan_id => $vlan_id);
ok($res, "Successfully deleted vlan");

$vlans = $vce->network_model->get_vlans();
ok(@{$vlans} == 1, "JSON has proper number of vlans");

$res = $vce->network_model->delete_vlan( vlan_id => $vlan_id);
ok(!$res, "Unable to remove the circuit again because it isn't there");

$vlans = $vce->network_model->get_vlans();
ok(@{$vlans} == 1, "JSON has proper number of vlans");

$res = $vce->network_model->delete_vlan();
ok(!$res, "Unable to remove the circuit because it wasn't specified");

$vlans = $vce->network_model->get_vlans();
ok(@{$vlans} == 1, "JSON has proper number of vlans");
