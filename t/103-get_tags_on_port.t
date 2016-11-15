#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 9;

use GRNOC::WebService::Client;
use Data::Dumper;

my $client = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                             realm => 'VCE',
                                             uid => 'aragusa',
                                             passwd => 'unittester',
                                             debug => 0,
                                             timeout => 60 );

my $port_tags = $client->get_ports_tags( workgroup => 'ajco',
                                    switch => 'foobar',
                                    port => 'eth0/1' );

ok(defined($port_tags), "ports result was defined for AJ");

ok($port_tags->{'results'}->[0]->{'ports'}->[0]->{'port'} eq 'eth0/1', "returned proper port");

my $tags = $port_tags->{'results'}->[0]->{'ports'}->[0]->{'tags'};

my $is_ok = 1;

for(my $i=0;$i<100;$i++){
    if($tags->[$i] eq $i + 101){

    }else{
        warn $tags->[$i] . " ne " . $i + 101 . "\n";
        $is_ok = 0;
    }
}

ok($is_ok, "Expected range is correct");

my $port_tags = $client->get_ports_tags( workgroup => 'ajco',
                                         switch => 'foobar',
                                         port => ['eth0/1','eth0/2']  );

ok(defined($port_tags), "ports result was defined for AJ");

ok($port_tags->{'results'}->[0]->{'ports'}->[0]->{'port'} eq 'eth0/1', "returned proper port");
ok($port_tags->{'results'}->[0]->{'ports'}->[1]->{'port'} eq 'eth0/2', "returned proper port");

$is_ok = 1;
$tags = $port_tags->{'results'}->[0]->{'ports'}->[0]->{'tags'};
for(my $i=0;$i<100;$i++){
    if($tags->[$i] eq $i + 101){

    }else{
        warn $tags->[$i] . " ne " . $i + 101 . "\n";
        $is_ok = 0;
    }
}
ok($is_ok, "Expected range is correct");
$is_ok = 1;
$tags = $port_tags->{'results'}->[0]->{'ports'}->[1]->{'tags'};
for(my $i=0;$i<100;$i++){
    if($tags->[$i] eq $i + 101){

    }else{
        warn $tags->[$i] . " ne " . $i + 101 . "\n";
        $is_ok = 0;
    }
}
ok($is_ok, "Expected range is correct");

my $port_tags = $client->get_ports_tags( workgroup => 'edco',
                                         switch => 'foobar',
                                         port => 'eth0/1'  );

ok(defined($port_tags->{'error'}) && $port_tags->{'error'}->{'msg'} eq 'User aragusa not in specified workgroup edco');
