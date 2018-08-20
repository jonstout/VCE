#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 7;

use GRNOC::WebService::Client;
use Data::Dumper;

`cp t/etc/nm1.sqlite.orig2 t/etc/nm1.sqlite`;

my $client = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                             realm => 'VCE',
                                             uid => 'aragusa',
                                             passwd => 'unittester',
                                             debug => 0,
                                             timeout => 60 );

my $workgroups = $client->get_workgroups();

ok(defined($workgroups), "Workroups result was defined for AJ");

ok($workgroups->{'results'}->[0]->{'workgroups'}->[0] eq 'ajco', "Proper workgroup was returned for aj");

my $client2 = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                              realm => 'VCE',
                                              uid => 'ebalas',
                                              passwd => 'unittester',
                                              debug => 0,
                                              timeout => 60 );

$workgroups = $client2->get_workgroups();

ok(defined($workgroups), "Workgroups result was defined for Ed");

ok($workgroups->{'results'}->[0]->{'workgroups'}->[1] eq 'edco', "Proper workgroup 1 was returned for ed");

ok($workgroups->{'results'}->[0]->{'workgroups'}->[0] eq 'admin', "Proper workgroup 2 was returned for ed");


my $client3 = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                              realm => 'VCE',
                                              uid => 'foobar',
                                              passwd => 'unittester',
                                              debug => 0,
                                              timeout => 60 );

$workgroups = $client3->get_workgroups();

ok(defined($workgroups), "Workgroups result was defined for foobar");

ok($#{$workgroups->{'results'}->[0]->{'workgroups'}} == -1, "No workgroup results for foobar");
