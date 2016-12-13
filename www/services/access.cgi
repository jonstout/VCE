#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;

use VCE::Services::Access;

our $access_services;

if(!defined($access_services)){

    if($ENV{'TESTING'}){
        warn "TESTING!!!!\n";
        warn Dumper($ENV{'CONFIG_FILE'});
        warn Dumper($ENV{'NETWORK_MODEL_FILE'});
        $access_services = VCE::Services::Access->new( config_file => $ENV{'CONFIG_FILE'},
                                                       network_model_file => $ENV{'NETWORK_MODEL_FILE'},
                                                       rabbit_mq => { user => 'guest',
                                                                      pass => 'guest',
                                                                      host => 'localhost',
                                                                      port => '5672'});
    }else{
        $access_services = VCE::Services::Access->new( config_file => '/etc/vce/access_policy.xml',
                                                       network_model_file => '/var/run/vce/network_model.json',
                                                       rabbit_mq => { user => 'guest',
                                                                      pass => 'guest',
                                                                      host => 'localhost',
                                                                      port => '5672'});
    }
}

$access_services->handle_request();

