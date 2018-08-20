#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 8;

use GRNOC::WebService::Client;
use Data::Dumper;
use Test::Deep;

`cp t/etc/nm1.sqlite.orig2 t/etc/nm1.sqlite`;

my $client = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                             realm => 'VCE',
                                             uid => 'aragusa',
                                             passwd => 'unittester',
                                             debug => 0,
                                             timeout => 60 );

my $switches = $client->get_switches( workgroup => 'ajco' );
ok(defined($switches), "switches result was defined for AJ");

cmp_deeply($switches->{'results'}->[0],  {
    'switch' => [
        {
            'vlans' => [
                2,
                3
            ],
            'ports' => [
                'eth0/3',
                'eth0/2',
                'eth0/1'
            ],
            'name' => 'foobar',
            'description' => undef
        }
    ]
}, "Proper switch was returned for aj");

$switches = $client->get_switches( workgroup => 'edco' );

ok(defined($switches), "switches result returned even without workgroup access");

ok(defined($switches->{'error'}) && $switches->{'error'}->{'msg'} eq 'User aragusa not in specified workgroup edco');

my $client2 = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                              realm => 'VCE',
                                              uid => 'ebalas',
                                              passwd => 'unittester',
                                              debug => 0,
                                              timeout => 60 );

$switches = $client2->get_switches( workgroup => 'edco' );
ok(defined($switches), "Switch result was defined for Ed");

cmp_deeply($switches->{'results'}->[0], {
    'switch' => [
        {
            'vlans' => [
                1
            ],
            'ports' => [
                'eth0/3',
                'eth0/2',
                'eth0/1'
            ],
            'name' => 'foobar',
            'description' => undef
        }
    ]
}, "Proper switch was returned for ed");

my $client3 = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                              realm => 'VCE',
                                              uid => 'foobar',
                                              passwd => 'unittester',
                                              debug => 0,
                                              timeout => 60 );

$switches = $client3->get_switches( workgroup => 'edco' );

ok(defined($switches), "switch result was defined for foobar");

ok(defined($switches->{'error'}) && $switches->{'error'}->{'msg'} eq 'User foobar not in specified workgroup edco');
