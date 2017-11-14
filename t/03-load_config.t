#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Test::More tests => 2;
use Test::Deep;
use VCE;
use GRNOC::Log;

my $logger = GRNOC::Log->new( level => 'ERROR');


my $vce = VCE->new( config_file => "./t/etc/test_config.xml", network_model_file => "t/etc/nm1.json");

ok(defined($vce), "was able to create VCE object");

my $workgroups = $vce->config->{'workgroups'};

cmp_deeply($workgroups, {
    'admin' => {
        'admin' => 1,
        'user' => {
            'ebalas' => {}
        },
        'name' => 'admin',
        'description' => 'admin workgroup'
    },
    'edco' => {
        'admin' => undef,
		'user' => {
		    'stan' => {},
		    'ebalas' => {}
		},
		'name' => 'edco',
		'description' => 'this is edcos exchange point access workgroup'
	},
    'ajco' => {
        'admin' => undef,
        'user' => {
            'aragusa' => {},
            'jonstout' => {}
        },
        'name' => 'ajco',
        'description' => 'this is ajcos exchange point access workgroup'
    }
});
