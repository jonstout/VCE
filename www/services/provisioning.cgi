#!/usr/bin/perl

use strict;
use warnings;

use GRNOC::Log;
use VCE::Services::Provisioning;

our $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf');
our $provisioning_services;

if($ENV{'TESTING'}){
    $provisioning_services = VCE::Services::Provisioning->new( config_file => $ENV{'CONFIG_FILE'},
                                                               network_model_file => $ENV{'NETWORK_MODEL_FILE'},
                                                               rabbit_mq => { user => 'guest',
                                                                              pass => 'guest',
                                                                              host => 'localhost',
                                                                              port => '5672'} );
}else{
    $provisioning_services = VCE::Services::Provisioning->new( config_file => '/etc/vce/access_policy.xml',
                                                               network_model_file => '/var/lib/vce/database.sqlite',
                                                               rabbit_mq => { user => 'guest',
                                                                              pass => 'guest',
                                                                              host => 'localhost',
                                                                              port => '5672'});
}


$provisioning_services->handle_request();

