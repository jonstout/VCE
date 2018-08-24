#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 14;
use Test::Deep;

use VCE;
use GRNOC::Log;

`cp t/etc/nm1.sqlite.orig2 t/etc/nm1.sqlite`;

my $logger = GRNOC::Log->new( level => 'ERROR');

my $vce = VCE->new( config_file => './t/etc/test_config.xml',
                    db => "t/etc/nm1.sqlite",
                    network_model_file => "t/etc/nm1.sqlite");

ok(defined($vce), "VCE Object created");

my $access = $vce->access->workgroup_has_access_to_port( workgroup => 'ajco',
							 switch => 'foobar',
							 port => 'eth0/1');

ok($access, "ajco has access to eth0/1");

$access = $vce->access->workgroup_has_access_to_port( workgroup => 'ajco',
                                                         switch => 'foobar',
                                                         port => 'eth0/1',
							 vlan => 101);

ok($access, "ajco has access to eth0/1 vlan 101");

$access = $vce->access->workgroup_has_access_to_port( workgroup => 'ajco',
                                                         switch => 'foobar',
                                                         port => 'eth0/1',
                                                         vlan => 200);

ok($access, "ajco has access to eth0/1 vlan 200");

$access = $vce->access->workgroup_has_access_to_port( workgroup => 'ajco',
                                                         switch => 'foobar',
                                                         port => 'eth0/1',
                                                         vlan => 201);

ok(!$access, "ajco does not have access to eth0/1 vlan 201");

$access = $vce->access->workgroup_has_access_to_port( workgroup => 'ajco',
						      switch => 'foobar',
						      port => 'eth0/1',
						      vlan => 100);

ok(!$access, "ajco does not access to eth0/1 vlan 100");

$access = $vce->access->workgroup_has_access_to_port( workgroup => 'ajco',
                                                         switch => 'foobar',
                                                         port => 'eth0/1',
                                                         vlan => 150);

ok($access, "ajco has access to eth0/1 vlan 150");

$access = $vce->access->workgroup_has_access_to_port( workgroup => 'edco',
                                                         switch => 'foobar',
                                                         port => 'eth0/2',
                                                         vlan => 100);

ok($access, "edco has access to eth0/2 vlan 100");

$access = $vce->access->workgroup_has_access_to_port( workgroup => 'ajco',
                                                         switch => 'foobar',
                                                         port => 'eth0/1',
                                                         vlan => 101);

ok($access, "ajco has access to eth0/1 vlan 101");

$access = $vce->access->workgroup_has_access_to_port( workgroup => 'ajco',
                                                      switch => 'foobar',
                                                      port => 'eth0/1',
                                                      vlan => 2000);

ok(!$access, "ajco has access to eth0/1 vlan 2000");


$access = $vce->access->workgroup_has_access_to_port( 
                                                      switch => 'foobar',
                                                      port => 'eth0/1',
                                                      vlan => 2000);

ok(!$access, "proper result when no workgroup specified");


$access = $vce->access->workgroup_has_access_to_port( workgroup => 'ajco',
                                                      port => 'eth0/1',
                                                      vlan => 2000);

ok(!$access, "proper result when no switch specified");


$access = $vce->access->workgroup_has_access_to_port( workgroup => 'ajco',
                                                      switch => 'foobar',
                                                    
                                                      vlan => 2000);

ok(!$access, "proper result when no port specified");


$access = $vce->access->workgroup_has_access_to_port( workgroup => 'ajco',
                                                      switch => 'foobar1',
                                                      port => 'eth0/1',
                                                      vlan => 2000);

ok(!$access, "proper result when non-existing switch specified");

