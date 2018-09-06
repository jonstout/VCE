#!/usr/bin/perl

use strict;
use warnings;

use GRNOC::Config;
use GRNOC::Log;

use VCE::Services::Switch;


if (!$ENV{TESTING}) {
    $ENV{CONFIG_FILE} = '/etc/vce/access_policy.xml';
}


my $config = GRNOC::Config->new(
    config_file => $ENV{CONFIG_FILE},
    force_array => 1,
    schema      => '/etc/vce/config.xsd'
);

my $ok = $config->validate();
if (!$ok) {
    die $config->get_error()->{'backtrace'}->{'message'};
}


our $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf');
our $handler = VCE::Services::Switch->new(rabbit_mq => $config->get('/accessPolicy/rabbit')->[0]);

$handler->handle_request();
