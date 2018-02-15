#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 7;
use Test::Deep;

use VCE;

use GRNOC::Log;

`cp t/etc/nm1.sqlite.orig t/etc/nm1.sqlite`;

my $logger = GRNOC::Log->new( level => 'ERROR');

my $vce = VCE->new( config_file => './t/etc/test_config.xml', network_model_file => "t/etc/nm1.sqlite");

ok(defined($vce), "VCE object created");

my $workgroup_switches = $vce->access->get_workgroup_switches( workgroup => 'ajco');

ok(defined($workgroup_switches), "got back a valid result");

ok($#{$workgroup_switches} == 0, "got back the proper number of switches");

ok($workgroup_switches->[0] eq 'foobar', "got back the right switch");

$workgroup_switches = $vce->access->get_workgroup_switches( workgroup => 'fooco');

ok(defined($workgroup_switches), "got back an valid result");

ok($#{$workgroup_switches} == -1, "No switches in response");

$workgroup_switches = $vce->access->get_workgroup_switches();

ok(!defined($workgroup_switches), "got back undef when no workgroup specified");
