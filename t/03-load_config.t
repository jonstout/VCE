#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Test::More tests => 2;
use Test::Deep;
use VCE;
use GRNOC::Log;

my $logger = GRNOC::Log->new( level => 'ERROR');


my $vce = VCE->new( config_file => "./t/etc/test_config.xml");

ok(defined($vce), "was able to create VCE object");

my $workgroups = $vce->config->{'workgroups'};

cmp_deeply($workgroups, {
    'admin' => {
	'user' => {
	    'ebalas@iu.edu' => {}
	},
	'name' => 'admin',
	'description' => 'admin workgroup'
    },
	    'edco' => {
		'user' => {
		    'stan@iu.edu' => {},
		    'ebalas@iu.edu' => {}
		},
		'name' => 'edco',
		'description' => 'this is edcos exchange point access workgroup'
	},
		    'ajco' => {
			'user' => {
			    'aragusa@iu.edu' => {}
			},
			'name' => 'ajco',
			'description' => 'this is ajcos exchange point access workgroup'
		}
	   });
