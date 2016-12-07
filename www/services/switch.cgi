#!/usr/bin/perl

use strict;
use warnings;

use VCE::Services::Switch;

our $switch_services;

if(!defined($switch_services)){
    $switch_services = VCE::Services::Switch->new( rabbit_mq => { user => 'guest', pass => 'guest', host => 'localhost', port => '5672'} );
}

$switch_services->handle_request();
