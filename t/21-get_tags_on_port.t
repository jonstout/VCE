#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 4;
use Test::Deep;

use Data::Dumper;
use VCE;
use GRNOC::Log;


`cp t/etc/nm5.sqlite.orig2 t/etc/nm1.sqlite`;

my $logger = GRNOC::Log->new( level => 'ERROR');

my $vce = VCE->new(
    config_file => './t/etc/tag_config.xml',
    db => "t/etc/nm1.sqlite",
    network_model_file => "t/etc/nm1.sqlite"
);
ok(defined $vce, "created vce object");


my $tags = $vce->access->get_tags_on_port(
    workgroup => "charlie",
    switch => "foobar",
    port => "eth0/2"
);

ok(defined $tags, "got tags from get_tags_on_port");

my $expected_vlans = {};
my $ok = 1;

for (my $i = 2; $i <= 4094; $i++) {
    $expected_vlans->{$i} = 1;
}

foreach my $tag (@$tags) {
    if (!defined $expected_vlans->{$tag}) {
        warn "vlan $tag wasn't found";
        $ok = 0;
        last;
    }
    delete $expected_vlans->{$tag};
}

ok($ok, "all retrieved tags were expected");
ok(!%$expected_vlans, "all expected vlans were retrieved");
