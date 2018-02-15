#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 8;
use Test::Deep;

use VCE;
use GRNOC::Log;

`cp t/etc/nm1.sqlite.orig t/etc/nm1.sqlite`;

my $logger = GRNOC::Log->new( level => 'ERROR');

my $vce = VCE->new( config_file => './t/etc/test_config.xml', network_model_file => "t/etc/nm1.sqlite");

ok(defined($vce), "Created VCE Object");

my $tags = $vce->access->get_tags_on_port( workgroup => "ajco",
                                           switch => "foobar",
                                           port => "eth0/1");

ok(defined($tags), "Tags returned a true value");

my $is_ok = 1;

my $testable_tags = {};
foreach my $tag (@{$tags}) {
    $testable_tags->{$tag} = 1;
}
for (my $i=0; $i < 100; $i++) {
    if (!defined $testable_tags->{$i+101}) {
        warn "Tag " . ($i+101) . " wasn't found";
        $is_ok = 0;
        last;
    }
}

ok($is_ok, "Expected range is correct");

ok(!defined($vce->access->get_tags_on_port( workgroup => "ajco",
                                            port => "eth0/1")), "proper error handling without switch");

ok(!defined($vce->access->get_tags_on_port( switch => "foobar",
                                            port => "eth0/1")), "proper error handling without workgroup");

ok(!defined($vce->access->get_tags_on_port( workgroup => "ajco",
                                            switch => "foobar")), "proper error handling without port");
$tags = $vce->access->get_tags_on_port( workgroup => "ajco",
                                        switch => "foobar",
                                        port => "eth1/1");
ok($#{$tags} == -1, "proper results when non-existent port specified");

$tags = $vce->access->get_tags_on_port( workgroup => "stoutco",
                                        switch => "foobar",
                                        port => "eth0/1");
ok($#{$tags} == -1,  "proper results when non-existent workgroup specified");
