#!/usr/bin/perl

use strict;
use warnings;

use GRNOC::Log;
use VCE::Services::Workgroup;

our $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf');
our $workgroup_services;

if(!defined($workgroup_services)){
    $workgroup_services = VCE::Services::Workgroup->new( rabbit_mq => {
            user => 'guest',
            pass => 'guest',
            host => 'localhost',
            port => '5672'
        }
    );
}

$workgroup_services->handle_request();
