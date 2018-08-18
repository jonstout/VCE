#!/usr/bin/perl

use strict;
use warnings;

use GRNOC::Log;
use VCE::Services::Interface;

our $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf');
our $interface_services;

if(!defined($interface_services)){
    $interface_services = VCE::Services::Interface->new( rabbit_mq => {
            user => 'guest',
            pass => 'guest',
            host => 'localhost',
            port => '5672'
        }
    );
}

$interface_services->handle_request();
