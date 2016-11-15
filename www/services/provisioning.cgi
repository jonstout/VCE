#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/aragusa/VCE/lib';

use GRNOC::Log;
use VCE::Services::Provisioning;

my $logger = GRNOC::Log->new( config => '/etc/vce/apache_logging.conf');

our $provisioning_services;

if($ENV{'TESTING'}){
    $provisioning_services = VCE::Services::Provisioning->new( config_file => $ENV{'CONFIG_FILE'},
                                                               network_model_file => $ENV{'NETWORK_MODEL_FILE'} );
}else{
    $provisioning_services = VCE::Services::Provisioning->new(  );
}


$provisioning_services->handle_request();

