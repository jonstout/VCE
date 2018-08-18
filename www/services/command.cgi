#!/usr/bin/perl

use strict;
use warnings;

use GRNOC::Log;
use VCE::Services::Command;

our $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf');
our $command_services;

if(!defined($command_services)){
    $command_services = VCE::Services::Command->new( rabbit_mq => { user => 'guest', pass => 'guest', host => 'localhost', port => '5672'} );
}

$command_services->handle_request();
