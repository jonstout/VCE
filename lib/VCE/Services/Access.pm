#!/usr/bin/perl

package VCE::Services::Access;

use strict;
use warnings;

use Moo;

use VCE::Access;

use GRNOC::Log;
use GRNOC::RabbitMQ;
use GRNOC::WebService::Dispatcher;
use GRNOC::WebService::Method;
use GRNOC::WebService::Regex;

has access => (is => 'rwp');
has logger => (is => 'rwp');
has dispatcher => (is => 'rwp');

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE::Services::Switch");
    $self->_set_logger($logger);

    $self->_set_access( VCE::Access->new() );

    my $dispatcher = GRNOC::WebService::Dispatcher->new();

    $self->register_webservice_methods($dispatcher);

    $self->_set_dispatcher($dispatcher);

    return $self;
}

sub register_webservice_methods{
    my $self = shift;
    my $d = shift;

    my $method = GRNOC::WebService::Method->new(
        name => "get_workgroups",
        description => "returns a list of workgroups available to a user",
        callback => sub{ return $self->get_workgroups(@_) });

    $d->register_method($method);

}

sub handle_request{
    my $self = shift;

    $self->dispatcher->handle_request();
}


sub get_workgroups{
    my $self = shift;

    
   
}


1;
