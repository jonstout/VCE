#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 13;
use Test::Deep;

use VCE;
use JSON::XS;
use GRNOC::Log;


sub _read_config{

    my $str;
    open(my $fh, "<", "./t/etc/nm3.json");
    while(my $line = <$fh>){
        $str .= $line;
    }
    my $json = decode_json($str);

    return $json;
}


my $logger = GRNOC::Log->new( level => 'ERROR');

#remove our temprorary nm file
`rm ./t/etc/nm3.json`;

my $vce = VCE->new( config_file => './t/etc/test_config.xml',
                    network_model_file => './t/etc/nm3.json'  );

ok(defined($vce), "VCE object created");

my $vlans = $vce->network_model->get_vlans();

ok($#{$vlans} == -1, "New configuration created!");

my $vlan_id = $vce->network_model->add_vlan( description => '13-delete_vlan circuit 1',
                                             workgroup => 'ajco',
                                             username => 'aragusa',
                                             switch => 'foobar',
                                             vlan => 101,
                                             endpoints => [{ port => 'eth0/1'},
                                                           { port => 'eth0/2'}]);

ok(defined($vlan_id), "VLAN was create!");

my $vlan_details = $vce->network_model->get_vlan_details( vlan_id => $vlan_id);

ok(defined($vlan_details), "VLAN Was found in the configuration");

my $json = _read_config();

my @vlan_ids = (keys %{$json->{'vlans'}});
ok($#vlan_ids == 0, "JSON has proper number of vlans");

$vlan_id = $vce->network_model->add_vlan( description => '12-delete_vlan circuit 2',
                                          workgroup => 'ajco',
                                          username => 'aragusa',
                                          switch => 'foobar',
                                          vlan => 102,
                                          endpoints => [{ port => 'eth0/1'},
                                                        { port => 'eth0/2'}]);

ok(defined($vlan_id), "Second circuit created!");

$json = _read_config();

@vlan_ids = (keys %{$json->{'vlans'}});
ok($#vlan_ids == 1, "JSON has proper number of vlans");

#ok delete the second only
my $res = $vce->network_model->delete_vlan( vlan_id => $vlan_id);
ok($res, "Successfully deleted vlan");

$json = _read_config();

@vlan_ids = (keys %{$json->{'vlans'}});
ok($#vlan_ids == 0, "JSON has proper number of vlans after edit");

$res = $vce->network_model->delete_vlan( vlan_id => $vlan_id);

ok(!$res, "Unable to remove the circuit again because it isn't there");

$json = _read_config();

@vlan_ids = (keys %{$json->{'vlans'}});
ok($#vlan_ids == 0, "JSON has proper number of vlans after edit");

$res = $vce->network_model->delete_vlan( );

ok(!$res, "Unable to remove the circuit because it wasn't specified");

$json = _read_config();

@vlan_ids = (keys %{$json->{'vlans'}});
ok($#vlan_ids == 0, "JSON has proper number of vlans after edit");
