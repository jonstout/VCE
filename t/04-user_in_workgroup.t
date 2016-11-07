#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 7;
use Test::Deep;

use VCE;

use GRNOC::Log;

my $logger = GRNOC::Log->new( level => 'ERROR');

my $vce = VCE->new( config_file => './t/etc/test_config.xml');

ok(defined($vce), "VCE object created");

my $user_in_workgroup = $vce->access->user_in_workgroup( username => 'aragusa@iu.edu',
							 workgroup => 'ajco');

ok($user_in_workgroup, "AJ is in aj-co");

$user_in_workgroup = $vce->access->user_in_workgroup( username => 'aragusa@iu.edu',
						      workgroup => 'edco');

ok(!$user_in_workgroup, "AJ is not in ed-co");

$user_in_workgroup = $vce->access->user_in_workgroup( username => 'foo@iu.edu',
                                                      workgroup => 'ajco');

ok(!$user_in_workgroup, "User foo does not exist");

$user_in_workgroup = $vce->access->user_in_workgroup( username => 'aragusa@iu.edu',
                                                      workgroup => 'doesnt_exist');

ok(!$user_in_workgroup, "workgroup doesn't exist");


$user_in_workgroup = $vce->access->user_in_workgroup( username => 'ebalas@iu.edu',
                                                      workgroup => 'admin');

ok($user_in_workgroup, "Ed is in admin");

$user_in_workgroup = $vce->access->user_in_workgroup( username => 'ebalas@iu.edu',
                                                      workgroup => 'edco');

ok($user_in_workgroup, "Ed is also in edco");
