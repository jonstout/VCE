#!/usr/bin/perl

use strict;
use warnings;

use GRNOC::Log;
use VCE::Services::User;

our $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf');
our $user_services;

if(!defined($user_services)){
    $user_services = VCE::Services::Switch->new( rabbit_mq => {
            user => 'guest',
            pass => 'guest',
            host => 'localhost',
            port => '5672'
        }
    );
}

$user_services->handle_request();
