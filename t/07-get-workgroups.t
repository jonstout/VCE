#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 5;
use Test::Deep;

use VCE;
use GRNOC::Log;

`cp t/etc/nm1.sqlite.orig2 t/etc/nm1.sqlite`;

my $logger = GRNOC::Log->new( level => 'ERROR');

my $vce = VCE->new(
    config_file => './t/etc/test_config.xml',
    db => "t/etc/nm1.sqlite",
    network_model_file => "t/etc/nm1.sqlite"
);

ok(defined($vce), "Created VCE Object");

my $workgroups = $vce->get_workgroups();

#cmp_deeply($workgroups, ['admin','edco','ajco']);
cmp_deeply($workgroups, ['admin','ajco','edco']);

$workgroups = $vce->get_workgroups( username => 'aragusa' );

cmp_deeply($workgroups, ['ajco']);

$workgroups = $vce->get_workgroups( username => 'ebalas' );

cmp_deeply($workgroups, ['admin','edco']);

$workgroups = $vce->get_workgroups( username => 'foo' );

cmp_deeply($workgroups, []);
