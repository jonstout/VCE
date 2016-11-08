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

sub BUILD{
    my ($self) = @_;
    
    my $logger = GRNOC::Log->get_logger("VCE::Services::Switch");
    $self->_set_logger($logger);    

    $self->_set_access( VCE::Access->new() );

    my $client = GRNOC::RabbitMQ::Client->new( );
    
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

sub handle_request{
    my $self = shift;
    
    $self->dispatcher->handle_request();
}


1;
