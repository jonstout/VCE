#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/aragusa/VCE/lib';

use VCE::Services::Switch;

our $switch_services;

if(!defined($switch_services)){
    $switch_services = VCE::Services::Switch->new( );
}

$switch_services->handle_request();
