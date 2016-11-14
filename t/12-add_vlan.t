#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 19;
use Test::Deep;

use VCE;
use JSON::XS;
use GRNOC::Log;

my $logger = GRNOC::Log->new( level => 'ERROR');

#remove our temprorary nm file
`rm ./t/etc/nm2.json`;

my $vce = VCE->new( config_file => './t/etc/test_config.xml',
                    network_model_file => './t/etc/nm2.json'  );

ok(defined($vce), "VCE object created");

my $vlans = $vce->network_model->get_vlans();

ok($#{$vlans} == -1, "New configuration created!");

my $vlan_id = $vce->network_model->add_vlan( description => '12-addvlan circuit 1',
                                             workgroup => 'ajco',
                                             username => 'aragusa',
                                             endpoints => [{ switch => 'foobar',
                                                             port => 'eth0/1',
                                                             vlan => 101},
                                                           {switch => 'foobar',
                                                            port => 'eth0/2',
                                                            vlan => 101}]);

ok(defined($vlan_id), "VLAN was create!");

my $vlan_details = $vce->network_model->get_vlan_details( vlan_id => $vlan_id);

ok(defined($vlan_details), "VLAN Was found in the configuration");
ok($vlan_details->{'workgroup'} eq 'ajco', "proper workgroup");
ok($vlan_details->{'username'} eq 'aragusa', "proper user");
ok($vlan_details->{'description'} eq '12-addvlan circuit 1');
ok($#{$vlan_details->{'endpoints'}} == 1, "proper number of endpoints");

ok($vlan_details->{'endpoints'}->[0]->{'switch'} eq 'foobar', "proper switch for ep 1");
ok($vlan_details->{'endpoints'}->[0]->{'port'} eq 'eth0/1', "proper port for ep 1");
ok($vlan_details->{'endpoints'}->[0]->{'tag'} eq '101', "proper tag for ep 1");

ok($vlan_details->{'endpoints'}->[1]->{'switch'} eq 'foobar', "proper switch for ep 2");
ok($vlan_details->{'endpoints'}->[1]->{'port'} eq 'eth0/2', "proper port for ep 2");
ok($vlan_details->{'endpoints'}->[1]->{'tag'} eq '101', "proper tag for ep 2");


$vlan_id = $vce->network_model->add_vlan( description => '12-addvlan circuit 2 should fail because vlan_id already there',
                                          workgroup => 'ajco',
                                          username => 'aragusa',
                                          vlan_id => $vlan_id,
                                          endpoints => [{ switch => 'foobar',
                                                          port => 'eth0/1',
                                                          vlan => 102},
                                                        {switch => 'foobar',
                                                         port => 'eth0/2',
                                                         vlan => 102}]);

ok(!defined($vlan_id), "VLAN with this ID already exists couldn't add");

$vlan_id = $vce->network_model->add_vlan( description => '12-addvlan circuit 3 should fail',
                                          workgroup => 'ajco',
                                          username => 'aragusa',
                                          endpoints => [{ switch => 'foobar',
                                                          port => 'eth0/1',
                                                          vlan => 101},
                                                        {switch => 'foobar',
                                                         port => 'eth0/2',
                                                         vlan => 101}]);

ok(!defined($vlan_id), "Prevented provisoning of vlan tag already in use");

$vlan_id = $vce->network_model->add_vlan( description => '12-addvlan circuit 4 should fail because vlan_id already there',
                                          workgroup => 'ajco',
                                          username => 'aragusa',
                                          endpoints => [{ switch => 'foobar',
                                                          port => 'eth0/1',
                                                          vlan => 102},
                                                        {switch => 'foobar',
                                                         port => 'eth0/2',
                                                         vlan => 102}]);
ok(defined($vlan_id), "Was able to create a second vlan with different VLAN IDs");

my $str;
open(my $fh, "<", "./t/etc/nm2.json");
while(my $line = <$fh>){
    $str .= $line;
}
my $json = decode_json($str);

ok(defined($json), "JSON was defined");

my @vlan_ids = (keys %{$json->{'vlans'}});

ok($#vlan_ids == 1, "proper number of VLANs defined");


