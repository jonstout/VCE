#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/aragusa/VCE/lib';

use GRNOC::Log;
use VCE::Services::Provisioning;

my $logger = GRNOC::Log->new( config => '/etc/vce/apache_logging.conf');

our $provisioning_services;

if(!defined($provisioning_services)){
    $provisioning_services = VCE::Services::Provisioning->new( );	
}

$provisioning_services->handle_request();

