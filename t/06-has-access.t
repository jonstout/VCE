#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 12;
use Test::Deep;

use VCE;
use GRNOC::Log;

my $logger = GRNOC::Log->new( level => 'DEBUG');

my $vce = VCE->new( config_file => './t/etc/test_config.xml');

ok(defined($vce), "Created VCE Object");

my $access = $vce->access->has_access( switch => 'foobar',
				       port => 'eth0/1',
				       username => 'aragusa',
				       workgroup => 'ajco');

ok($access, "AJ via ajco has access to eth0/1");

$access = $vce->access->has_access( switch => 'foobar',
				    port => 'eth0/1',
				    vlan => 101,
				    username => 'aragusa',
				    workgroup => 'ajco');

ok($access, "AJ via ajco has access to eth0/1 vlan 101");

$access = $vce->access->has_access( switch => 'foobar',
                                    port => 'eth0/1',
                                    vlan => 150,
                                    username => 'aragusa',
                                    workgroup => 'ajco');

ok($access, "AJ via ajco has access to eth0/1 vlan 150");

$access = $vce->access->has_access( switch => 'foobar',
                                    port => 'eth0/1',
                                    vlan => 100,
                                    username => 'aragusa',
                                    workgroup => 'ajco');

ok(!$access, "AJ via ajco does not have access to eth0/1 vlan 100");

$access = $vce->access->has_access( switch => 'foobar',
                                    port => 'eth0/1',
                                    vlan => 100,
                                    username => 'aragusa',
                                    workgroup => 'edco');

ok(!$access, "AJ not in edco");


$access = $vce->access->has_access( switch => 'foobar1',
                                    port => 'eth0/1',
                                    vlan => 100,
                                    username => 'aragusa',
                                    workgroup => 'ajco');

ok(!$access, "No switch called foobar1");

$access = $vce->access->has_access( switch => 'foobar',
                                    port => 'eth0/1',
                                    vlan => 100,
                                    username => 'ebalas',
                                    workgroup => 'edco');

ok($access, "Ed via Edco has access to eth0/1 vlan 100");

$access = $vce->access->has_access( 
                                    port => 'eth0/1',
                                    vlan => 100,
                                    username => 'ebalas',
                                    workgroup => 'edco');

ok(!$access, "proper result when switch not specified");

$access = $vce->access->has_access(
                                    switch => 'foobar',
                                    vlan => 100,
                                    username => 'ebalas',
                                    workgroup => 'edco');

ok(!$access, "proper result when port not specified");

$access = $vce->access->has_access( switch => 'foobar',
                                    port => 'eth0/1',
                                    vlan => 100,
                                    workgroup => 'edco');

ok(!$access, "proper result when user not specified");

$access = $vce->access->has_access( switch => 'foobar',
                                    port => 'eth0/1',
                                    username => 'ebalasasdf',
                                    vlan => 100);

ok(!$access, "proper result when workgroup not specified");
