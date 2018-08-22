#!/usr/bin/perl

use strict;
use warnings;

use GRNOC::Log;
use VCE::Services::ACL;

our $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf');
our $acl_services;

if(!defined($acl_services)){
    $acl_services = VCE::Services::ACL->new( rabbit_mq => {
            user => 'guest',
            pass => 'guest',
            host => 'localhost',
            port => '5672'
        }
    );
}

$acl_services->handle_request();
