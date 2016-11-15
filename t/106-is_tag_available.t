#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 9;
use Test::Deep;
use GRNOC::WebService::Client;
use Data::Dumper;

`cp t/etc/nm1.json.orig t/etc/nm1.json`;

my $client = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                             realm => 'VCE',
                                             uid => 'aragusa',
                                             passwd => 'unittester',
                                             debug => 0,
                                             timeout => 60 );

my $avail = $client->is_tag_available( workgroup => 'ajco',
                                      switch => 'foobar',
                                      port => 'eth0/1',
                                      tag => 110);

ok(defined($avail), "availability result was defined for AJ");
ok($avail->{'results'}->[0]->{'available'}, "Tag is available");

$avail = $client->is_tag_available( workgroup => 'ajco',
                                    switch => 'foobar',
                                    port => 'eth0/1',
                                    tag => 102);

ok(defined($avail), "availability result was defined for AJ");
ok(!$avail->{'results'}->[0]->{'available'}, "Tag is 102 not available for ajco");

$avail = $client->is_tag_available( workgroup => 'ajco',
                                    switch => 'foobar',
                                    port => 'eth0/1',
                                    tag => 90);

ok(defined($avail), "availability result was defined for AJ");
ok(!$avail->{'results'}->[0]->{'available'}, "Tag 90 is not available to ajco");
ok($avail->{'error'}->{'msg'} eq 'Workgroup ajco is not allowed tag 90 on foobar:eth0/1', "gave proper error message");
$avail = $client->is_tag_available( workgroup => 'edco',
                                    switch => 'foobar',
                                    port => 'eth0/1',
                                    tag => 90);

ok(defined($avail), "availability result was defined for AJ");
ok($avail->{'error'}->{'msg'} eq "User aragusa not in specified workgroup edco");
