#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 10;
use Test::Deep;

use VCE;
use GRNOC::Log;
use Data::Dumper;

my $logger = GRNOC::Log->new( level => 'ERROR');

my $vce = VCE->new( config_file => './t/etc/test_config.xml');

ok(defined($vce), "Created VCE Object");

ok($vce->access->workgroup_owns_port(workgroup => 'edco',
                                     port => 'eth0/1',
                                     switch => 'foobar' ), "Edco does own eth0/1 on foobar");
   
ok($vce->access->workgroup_owns_port(workgroup => 'ajco',
                                      port => 'eth0/2',
                                      switch => 'foobar'), "ajco does own eth0/2 on foobar" );

ok(!$vce->access->workgroup_owns_port(workgroup => 'ajco',
                                      port => 'eth0/1',
                                      switch => 'foobar'), "ajco does NOT own eth0/1 on foobar" );

ok(!$vce->access->workgroup_owns_port(workgroup => 'edco',
                                      port => 'eth0/2',
                                      switch => 'foobar'), "edco does NOT own eth0/2 on foobar" );

ok(!$vce->access->workgroup_owns_port(workgroup => 'edco',
                                      switch => 'foobar'), "no port specified" );

ok(!$vce->access->workgroup_owns_port(workgroup => 'edco',
                                      port => 'eth0/3',
                                      switch => 'foobar'), "unconfigured port specified" );

ok(!$vce->access->workgroup_owns_port(workgroup => 'edco',
                                      port => 'eth0/1',
                                      switch => 'asdf'), "unconfigured switch specified" );

ok(!$vce->access->workgroup_owns_port(workgroup => 'edco',
                                      port => 'eth0/1'), "no switch specified" );

ok(!$vce->access->workgroup_owns_port(port => 'eth0/1',
                                      switch => 'foobar'), "no workgroup specified" );
