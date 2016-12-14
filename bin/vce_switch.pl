#!/usr/bin/perl

use strict;
use warnings;
use lib './lib/';

use VCE;
use VCE::Switch;

use GRNOC::Log;

use GRNOC::CLI;
use Data::Dumper;

my $logger = GRNOC::Log->new( level => 'DEBUG');

my $cli = GRNOC::CLI->new();

my $username = $cli->get_input("username");
my $password = $cli->get_password("password");

my $switch = VCE::Switch->new( username => $username,
			       password => $password,
			       hostname => '156.56.6.220',
			       port => 22,
			       vendor => 'Brocade',
			       type => 'MLXe',
			       version => '5.8.0',
			       port => 22,
                               rabbit_mq => { host => 'localhost',
                                              user => 'guest',
                                              pass => 'guest',
                                              port => 5672});

if(defined($switch)){
    $switch->start();
}
