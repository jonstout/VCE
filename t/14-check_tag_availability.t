#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 10;
use Test::Deep;

use VCE;
use JSON::XS;
use GRNOC::Log;


sub _read_config{

    my $str;
    open(my $fh, "<", "./t/etc/nm4.json");
    while(my $line = <$fh>){
        $str .= $line;
    }
    my $json = decode_json($str);

    return $json;
}


my $logger = GRNOC::Log->new( level => 'ERROR');

#remove our temprorary nm file
`rm ./t/etc/nm4.json`;

my $vce = VCE->new( config_file => './t/etc/test_config.xml',
                    network_model_file => './t/etc/nm4.json'  );

ok(defined($vce), "VCE object created");

my $vlans = $vce->network_model->get_vlans();

ok($#{$vlans} == -1, "New configuration created!");

ok($vce->network_model->check_tag_availability( switch => 'foobar',
                                                port => 'eth0/1',
                                                tag => 101), "ok tag is available");

ok($vce->network_model->check_tag_availability( switch => 'foobar',
                                                port => 'eth0/1',
                                                tag => 2000), "ok tag is available");


my $vlan_id = $vce->network_model->add_vlan( description => '14-check_tag-availability circuit 1',
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

ok(!$vce->network_model->check_tag_availability( switch => 'foobar',
                                                port => 'eth0/1',
                                                tag => 101), "ok tag is not available available");

ok(!defined($vce->network_model->check_tag_availability( port => 'eth0/1',
                                                         tag => 101)), "returned proper result for no switch specified");

ok(!defined($vce->network_model->check_tag_availability( switch => 'foobar',
                                                         tag => 101)), "returned proper result for no switch specified");

ok(!defined($vce->network_model->check_tag_availability( port => 'eth0/1',
                                                         switch => 'foobar')), "returned proper result for no switch specified");
