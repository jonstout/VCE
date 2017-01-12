#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 5;
use Test::Deep;

use VCE;
use GRNOC::Log;
use Data::Dumper;

my $logger = GRNOC::Log->new( level => 'ERROR');

my $vce = VCE->new( config_file => './t/etc/test_config.xml', network_model_file => "t/etc/nm1.json");

ok(defined($vce), "Created VCE Object");

my $ports = $vce->access->workgroups_owned_ports(workgroup => 'edco');

cmp_deeply($ports, [{switch => 'foobar', port => 'eth0/1'}]);

$ports = $vce->access->workgroups_owned_ports(workgroup => 'ajco');

cmp_deeply($ports, [{switch => 'foobar', port => 'eth0/2'}]);

$ports = $vce->access->workgroups_owned_ports(workgroup => 'foo');

cmp_deeply($ports, []);

$ports = $vce->access->workgroups_owned_ports();

ok(!defined($ports), "when no workgroup specified get back undefined results");
