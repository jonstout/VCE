#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 10;

use GRNOC::WebService::Client;
use Data::Dumper;

my $client = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                             realm => 'VCE',
                                             uid => 'aragusa',
                                             passwd => 'unittester',
                                             debug => 0,
                                             timeout => 60 );

my $ports = $client->get_ports( workgroup => 'ajco',
                                switch => 'foobar' );

ok(defined($ports), "ports result was defined for AJ");

ok($ports->{'results'}->[0]->{'ports'}->[0]->{'port'} eq 'eth0/2', "Proper port 1 was returned for aj");
ok($ports->{'results'}->[0]->{'ports'}->[1]->{'port'} eq 'eth0/1', "Proper port 2 was returned for aj");

$ports = $client->get_ports( workgroup => 'edco', switch => 'foobar', );

ok(defined($ports), "ports result returned even without workgroup access");

ok(defined($ports->{'error'}) && $ports->{'error'}->{'msg'} eq 'User aragusa not in specified workgroup edco');

my $client2 = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                              realm => 'VCE',
                                              uid => 'ebalas',
                                              passwd => 'unittester',
                                              debug => 0,
                                              timeout => 60 );

$ports = $client2->get_ports( switch => 'foobar', workgroup => 'edco' );

ok(defined($ports), "Switch result was defined for Ed");

ok($ports->{'results'}->[0]->{'ports'}->[0]->{'port'} eq 'eth0/2', "Proper port 1 was returned for ed");
ok($ports->{'results'}->[0]->{'ports'}->[1]->{'port'} eq 'eth0/1', "Proper port 2 was returned for ed");

my $client3 = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                              realm => 'VCE',
                                              uid => 'foobar',
                                              passwd => 'unittester',
                                              debug => 0,
                                              timeout => 60 );

$ports = $client3->get_switches( workgroup => 'edco', switch => 'foobar' );

ok(defined($ports), "ports result was defined for foobar");

ok(defined($ports->{'error'}) && $ports->{'error'}->{'msg'} eq 'User foobar not in specified workgroup edco');
