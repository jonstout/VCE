#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 14;
use Test::Deep;

use VCE;
use JSON::XS;
use GRNOC::Log;


my $logger = GRNOC::Log->new( level => 'ERROR');

#remove our temprorary nm file
`cp t/etc/nm4.sqlite.orig t/etc/nm4.sqlite`;

my $vce = VCE->new( config_file => './t/etc/test_config.xml',
                    network_model_file => './t/etc/nm4.sqlite'  );

ok(defined($vce), "VCE object created");

my $vlans = $vce->network_model->get_vlans();

ok($#{$vlans} == -1, "New configuration created!");

ok($vce->network_model->check_tag_availability( switch => 'foobar',
                                                vlan => 101), "network model says tag is available");

ok($vce->network_model->check_tag_availability( switch => 'foobar',
                                                vlan => 2000), "network model tag is available");


ok($vce->is_tag_available( switch => 'foobar',
                           tag => 101), "vce says tag is available");

ok($vce->is_tag_available( switch => 'foobar',
                           tag => 2000), "vce says tag is available");


my $vlan_id = $vce->network_model->add_vlan( description => '14-check_tag-availability circuit 1',
                                             workgroup => 'ajco',
                                             username => 'aragusa',
                                             vlan => 101,
                                             switch => 'foobar',
                                             endpoints => [{ port => 'eth0/1' },
                                                           { port => 'eth0/2' }]);

ok(defined($vlan_id), "VLAN was create!");

my $vlan_details = $vce->network_model->get_vlan_details( vlan_id => $vlan_id);

ok(defined($vlan_details), "VLAN Was found in the configuration");

ok(!$vce->network_model->check_tag_availability( switch => 'foobar',
                                                 tag => 101), "ok tag is not available available");

ok(!defined($vce->network_model->check_tag_availability( tag => 101)), "returned proper result for no switch specified");

ok(!defined($vce->network_model->check_tag_availability( switch => 'foobar')), "returned proper result for no vlan specified");

ok(!$vce->is_tag_available( switch => 'foobar',
                            tag => 101), "ok tag is not available available");

ok(!defined($vce->is_tag_available( tag => 101)), "returned proper result for no switch specified");

ok(!defined($vce->is_tag_available( switch => 'foobar')), "returned proper result for no vlan specified");
