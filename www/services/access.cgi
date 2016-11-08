#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/aragusa/VCE/lib';

use VCE::Services::Access;

our $access_services;

if(!defined($access_services)){
    $access_services = VCE::Services::Access->new( );	
}

$access_services->handle_request();

