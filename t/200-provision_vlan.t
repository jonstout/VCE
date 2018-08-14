#!/usr/bin/perl

use strict;
use warnings;

#use Test::More skip_all => "Busted";
use Test::More tests => 19;
use Test::Deep;
use GRNOC::WebService::Client;
use AnyEvent::HTTP::LWP::UserAgent;
use GRNOC::RabbitMQ;
use GRNOC::RabbitMQ::Dispatcher;
use GRNOC::RabbitMQ::Method;
use JSON::XS;
use Data::Dumper;


`cp t/etc/nm1.sqlite.orig2 t/etc/nm1.sqlite`;

sub make_request{
    my $params = shift;
    my $query = new CGI($params);
    my $req = HTTP::Request->new( GET => "http://localhost:8529/vce/services/provisioning.cgi?" . $query->query_string() );
    $req->authorization_basic( 'aragusa', 'unittester' );
    return $req;
}

my $dispatcher = GRNOC::RabbitMQ::Dispatcher->new( user => 'guest',
                                                   pass => 'guest',
                                                   host => 'localhost',
                                                   timeout => 30,
                                                   port => 5672,
                                                   exchange => 'VCE',
                                                   topic => 'VCE.Switch.foobar' );


my $method = GRNOC::RabbitMQ::Method->new( name => "interface_tagged",
                                           callback => sub { return {success => 1} },
                                           description => "Add vlan tagged interface" );

$method->add_input_parameter( name        => "port",
                              description => "Name of the interface to add tag to",
                              required    => 1,
                              pattern     => $GRNOC::WebService::Regex::TEXT );

$method->add_input_parameter( name        => "vlan",
                              description => "VLAN number to use for tag",
                              required    => 1,
                              pattern     => $GRNOC::WebService::Regex::INTEGER );

$dispatcher->register_method($method);

$method = GRNOC::RabbitMQ::Method->new( name => "no_interface_tagged",
                                        callback => sub { return {success => 1}},
                                        description => "Remove vlan tagged interface" );
$method->add_input_parameter( name        => "port",
                              description => "Name of the interface to remove tag from",
                              required    => 1,
                              pattern     => $GRNOC::WebService::Regex::TEXT );
$method->add_input_parameter( name        => "vlan",
                              description => "VLAN number to use for tag",
                              required    => 1,
                              pattern     => $GRNOC::WebService::Regex::INTEGER );
$dispatcher->register_method($method);


my $client = GRNOC::WebService::Client->new( url => 'http://localhost:8529/vce/services/access.cgi',
                                             realm => 'VCE',
                                             uid => 'aragusa',
                                             passwd => 'unittester',
                                             debug => 0,
                                             timeout => 60 );

#GRNOC WebService is not async... but async would be so helpful so...
my $ua = AnyEvent::HTTP::LWP::UserAgent->new;

my $vlans = $client->get_vlans( workgroup => 'ajco' );

ok(defined($vlans), "Got a response");
warn Dumper($vlans);
ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 2, "Expected circuits found!");
# exit 1;
my $vlan;
my $req = make_request({ method => 'add_vlan',
                         description => 'Automated test suite!',
                         switch => 'foobar',
                         port =>['eth0/1','eth0/2'],
                         vlan => 104,
                         workgroup => 'ajco'});

my $response = $ua->simple_request_async($req)->recv;
if($response->is_success){
    my $content = $response->content;
    $vlan = decode_json($content);
} else {
    warn Dumper($response);
}

ok(defined($vlan), "got a response");
ok($vlan->{'results'}->[0]->{'success'} == 1, "Success provisioning!");
ok(defined($vlan->{'results'}->[0]->{'vlan_id'}), "Got a VLAN ID Back!");

$vlans = $client->get_vlans( workgroup => 'ajco');

ok(defined($vlans), "Got a valid response");
ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 3, "We now see that we have a VLAN!");

my $vlan_details = $client->get_vlan_details( vlan_id => $vlan->{'results'}->[0]->{'vlan_id'},
                                              workgroup => 'ajco');

ok(defined($vlan_details), "Got vlan details response");

delete $vlan_details->{'results'}->[0]->{'circuit'}->{'create_time'};
delete $vlan_details->{'results'}->[0]->{'circuit'}->{'vlan_id'};

cmp_deeply($vlan_details,{
    'results' => [
        {
            'circuit' => {
                'workgroup' => 'ajco',
                'status' => 'Active',
                'description' => 'Automated test suite!',
                'switch' => 'foobar',
                'vlan' => '104',
                'endpoints' => [
                    {
                        'port' => 'eth0/1'
                    },
                    {
                        'port' => 'eth0/2'
                    }
                    ],
                'username' => 'aragusa'
            }
        }
        ]
           });

$vlan = undef;
$req = make_request({ method => 'add_vlan',
                      description => 'Automated test suite!',
                      switch => 'foobar',
                      port =>['eth0/1','eth0/2'],
                      vlan => 104,
                      workgroup => 'ajco'});

$response = $ua->simple_request_async($req)->recv;
if($response->is_success){
    my $content = $response->content;
    $vlan = decode_json($content);
}
warn Dumper($vlan);
ok(defined($vlan), "Results was returned even though provisioning failed");
ok($vlan->{'results'}->[0]->{'success'} == 0, "Unable to provision because tags already in use!");
warn Dumper($vlan->{'error'}->{'msg'});
# exit 1;
ok($vlan->{'error'}->{'msg'} eq "Unable to add VLAN to the database. Please verify the VLAN does't already exist.", "Returned an error message saying why we couldn't provision");



$req = make_request({method => 'add_vlan',
                     description => "Automated test suite!",
                     switch => 'foobar',
                     port => ['eth0/1','eth0/2'],
                     vlan => '104',
                     workgroup => 'ajco'});

$response = $ua->simple_request_async($req)->recv;
if($response->is_success){
    my $content = $response->content;
    $vlan = decode_json($content);
}

ok(defined($vlan), "Results was returned even though provisioning failed");
ok($vlan->{'results'}->[0]->{'success'} == 0, "Unable to provision because tags already in use!");
warn Dumper($vlan->{'error'}->{'msg'});
ok($vlan->{'error'}->{'msg'} eq "Unable to add VLAN to the database. Please verify the VLAN does't already exist.", "Returned an error message saying why we couldn't provision");

$vlans = $client->get_vlans( workgroup => 'ajco');
ok(defined($vlans), "Got a valid response");
ok($#{$vlans->{'results'}->[0]->{'vlans'}} == 3, "Making sure we have the right number of circuits still");


$req = make_request({method => 'add_vlan',
                     description => "Automated test suite!",
                     switch => 'foobar',
                     port => ['eth0/1','eth0/2'],
                     vlan => '99',
                     workgroup => 'edco'});
                    
$response = $ua->simple_request_async($req)->recv;
if($response->is_success){
    my $content = $response->content;
    $vlan = decode_json($content);
}

ok(defined($vlan), "Got a valid response");
ok(defined($vlan->{'error'}) && $vlan->{'error'}->{'msg'} eq 'User aragusa not in specified workgroup edco');
