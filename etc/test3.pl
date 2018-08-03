use strict;
use warnings;

use Data::Dumper;
use GRNOC::Config;

use VCE::Device::Brocade::MLXe::5_8_0;

my $c = new GRNOC::Config(config_file => '/etc/vce/access_policy.xml');

my $user = $c->get('/accessPolicy/switch/@username')->[0];
my $pass = $c->get('/accessPolicy/switch/@password')->[0];
my $host = $c->get('/accessPolicy/switch/@ip')->[0];
my $port = $c->get('/accessPolicy/switch/@port')->[0];

my $device = VCE::Device::Brocade::MLXe::5_8_0->new(
    username => $user,
    password => $pass,
    hostname => $host,
    port     => $port
);
$device->connect();

warn "Adding!";

my $res = $device->connected;
warn Dumper($res);
