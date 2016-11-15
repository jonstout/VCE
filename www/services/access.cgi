#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use lib '/home/aragusa/VCE/lib';

use VCE::Services::Access;

our $access_services;

if(!defined($access_services)){

    if($ENV{'TESTING'}){
        warn "TESTING!!!!\n";
        warn Dumper($ENV{'CONFIG_FILE'});
        warn Dumper($ENV{'NETWORK_MODEL_FILE'});
        $access_services = VCE::Services::Access->new( config_file => $ENV{'CONFIG_FILE'},
                                                       network_model_file => $ENV{'NETWORK_MODEL_FILE'} );
    }else{
        $access_services = VCE::Services::Access->new(  );	
    }
}

$access_services->handle_request();

