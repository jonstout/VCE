#!/usr/bin/perl

use Database::Connection;
use Data::Dumper;

warn Dumper(Database::Connection);

my $db = Database::Connection->new('/var/lib/vce/network_model.sqlite');

$db->get_switch(1);
