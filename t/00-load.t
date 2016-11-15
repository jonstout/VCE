#!/usr/bin/perl

use Test::More tests => 5;

BEGIN {
        use_ok( 'VCE' );
        use_ok( 'VCE::Access' );
        use_ok( 'VCE::Services::Access' );
        use_ok( 'VCE::NetworkModel');
        use_ok( 'VCE::Services::Provisioning' );
}
