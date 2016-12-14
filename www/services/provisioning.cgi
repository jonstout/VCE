#!/usr/bin/perl

use strict;
use warnings;

use GRNOC::Log;
use VCE::Services::Provisioning;

our $logger;

our $provisioning_services;

if($ENV{'TESTING'}){
    $logger = GRNOC::Log->new( config => '/etc/vce/apache_logging.conf');
    $provisioning_services = VCE::Services::Provisioning->new( config_file => $ENV{'CONFIG_FILE'},
                                                               network_model_file => $ENV{'NETWORK_MODEL_FILE'},
                                                               rabbit_mq => { user => 'guest',
                                                                              pass => 'guest',
                                                                              host => 'localhost',
                                                                              port => '5672'} );
}else{
    $logger = GRNOC::Log->new( config => '/etc/vce/apache_logging.conf');
    $provisioning_services = VCE::Services::Provisioning->new( config_file => '/etc/vce/access_policy.xml',
                                                               network_model_file => '/var/run/vce/network_model.json',
                                                               rabbit_mq => { user => 'guest',
                                                                              pass => 'guest',
                                                                              host => 'localhost',
                                                                              port => '5672'});
}


$provisioning_services->handle_request();

