#!/usr/bin/perl

package VCE::Services::Switch;

use strict;
use warnings;

use Moo;
use GRNOC::Log;
use GRNOC::RabbitMQ::Client;
use GRNOC::WebService::Dispatcher;
use GRNOC::WebService::Method;
use GRNOC::WebService::Regex;

use VCE::Access;

has access => (is => 'rwp');
has logger => (is => 'rwp');
has rabbit_client => (is => 'rwp');
has dispatcher => (is => 'rwp');
has rabbit_mq => (is => 'rwp');

sub BUILD{
    my ($self) = @_;
    
    my $logger = GRNOC::Log->get_logger("VCE::Services::Switch");
    $self->_set_logger($logger);    

    $self->_set_access( VCE::Access->new() );

    my $client = GRNOC::RabbitMQ::Client->new( user => $self->rabbit_mq->{'user'},
					       pass => $self->rabbit_mq->{'pass'},
					       host => $self->rabbit_mq->{'host'},
					       timeout => 30,
					       port => $self->rabbit_mq->{'port'},
					       exchange => 'VCE',
					       topic => 'VCE.Switch.RPC' );
    
    $self->_set_rabbit_client( $client );
    
    my $dispatcher = GRNOC::WebService::Dispatcher->new();

    $self->register_webservice_methods($dispatcher);

    $self->_set_dispatcher($dispatcher);

    return $self;
}

sub register_webservice_methods{
    my $self = shift;
    my $d = shift;

    my $method = GRNOC::WebService::Method->new(
	name => "get_interfaces",
	description => "returns a list of interfaces and the interfaces details",
	callback => sub{ return $self->get_interfaces(@_) });
    
    $method->add_input_parameter( name => "interface_name",
				  pattern => $GRNOC::WebService::Regex::NAME,
				  required => 0,
				  multiple => 1,
				  description => "Interface name to query");

    $d->register_method($method);
				  
}

sub get_interfaces{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;
    
    my $interfaces = $self->rabbit_client->get_interfaces( interface_name => $p_ref->{'interface_name'}{'value'} )->{'results'};

    my @ints;
    foreach my $int (keys(%{$interfaces})){
	push(@ints,$interfaces->{$int});
    }

    return {results => \@ints};
}

sub handle_request{
    my $self = shift;
    
    $self->dispatcher->handle_request();
}


1;
