#!/usr/bin/perl

use strict;
use warnings;

use GRNOC::Log;
use VCE::Services::Access;

our $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf');
our $access_services;

if($ENV{'TESTING'}){
    eval {
        $access_services = VCE::Services::Access->new( config_file => $ENV{'CONFIG_FILE'},
                                                       network_model_file => $ENV{'NETWORK_MODEL_FILE'} );
    };
    if ($@) {
        warn "ERROR: $@";
    }
}else{
    $access_services = VCE::Services::Access->new( config_file => '/etc/vce/access_policy.xml',
                                                   network_model_file => '/var/lib/vce/network_model.sqlite' );
}

$access_services->handle_request();
