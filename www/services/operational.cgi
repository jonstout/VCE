#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;

use GRNOC::Log;
use VCE::Services::Operational;

our $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf');
our $operational_services;

if(!defined($operational_services)){

    if($ENV{'TESTING'}){
        warn "TESTING!!!!\n";
        warn Dumper($ENV{'CONFIG_FILE'});
        warn Dumper($ENV{'NETWORK_MODEL_FILE'});
        $operational_services = VCE::Services::Operational->new( config_file => $ENV{'CONFIG_FILE'},
                                                                 network_model_file => $ENV{'NETWORK_MODEL_FILE'},
                                                                 rabbit_mq => { user => 'guest', pass => 'guest', host => 'localhost', port => '5672'} );
    }else{
        $operational_services = VCE::Services::Operational->new( config_file => '/etc/vce/access_policy.xml',
                                                                 network_model_file => '/var/run/vce/network_model.json',
                                                                 rabbit_mq => { user => 'guest', pass => 'guest', host => 'localhost', port => '5672'});
    }
}

$operational_services->handle_request();

