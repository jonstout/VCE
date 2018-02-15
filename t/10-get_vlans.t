#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 8;
use Test::Deep;

use VCE;

use GRNOC::Log;

`cp t/etc/nm1.sqlite.orig t/etc/nm1.sqlite`;

my $logger = GRNOC::Log->new( level => 'ERROR');

my $vce = VCE->new( config_file => './t/etc/test_config.xml',
                    network_model_file => './t/etc/nm1.sqlite'  );

ok(defined($vce), "VCE object created");

my $vlans = $vce->network_model->get_vlans();

ok($#{$vlans} == 2, "Proper number of VLANs defined");

$vlans = $vce->network_model->get_vlans( workgroup => "ajco" );

ok($#{$vlans} == 1, "Proper number of VLANs defined");

ok($vlans->[1] eq '979f9708-7102-4762-8a6a-8e30ed80b88c', "ajco circuit 1 matches");
ok($vlans->[0] eq 'b0c0103e-b2dc-47cd-a687-c73dd9100fd2', "ajco circuit 2 matches");

$vlans = $vce->network_model->get_vlans( workgroup => "edco" );

ok($#{$vlans} == 0, "Proper number of VLANs defined");

ok($vlans->[0] eq '2806baa4-173c-4bdd-b552-c063a82e232f', "edco circuit 1 matches");

$vlans = $vce->network_model->get_vlans( workgroup => "foo" );

ok($#{$vlans} == -1, "Proper number of VLANs defined");
