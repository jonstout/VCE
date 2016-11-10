#!/usr/bin/perl

package VCE::Services::Access;

use strict;
use warnings;

use Moo;

use VCE;

use GRNOC::Log;
use GRNOC::RabbitMQ;
use GRNOC::WebService::Dispatcher;
use GRNOC::WebService::Method;
use GRNOC::WebService::Regex;

has vce=> (is => 'rwp');
has logger => (is => 'rwp');
has dispatcher => (is => 'rwp');

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE::Services::Switch");
    $self->_set_logger($logger);

    $self->_set_vce( VCE->new() );

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

    my $user = $ENV{'REMOTE_USER'};
    
    $self->logger->debug("Fetching workgroups for user: " . $user);
    return $self->vce->get_workgroups( username => $user );
}

sub get_ports{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;
    
    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $switch = $p_ref->{'switch'}{'value'};
    my $ports = $p_ref->{'ports'}{'value'};

    my $p = $self->vce->get_available_ports( username => $user, workgroup => $workgroup, switch => $switch, ports => $ports);
    return $p;
}

sub get_tags_on_port{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $switch = $p_ref->{'switch'}{'value'};
    my $port = $p_ref->{'port'}{'value'};

    my $tags = $self->vce->get_tags_on_port( username => $user, workgroup => $workgroup, switch => $switch, port => $port);
    return $tags;
}

sub is_tag_available{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};
    
    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $switch = $p_ref->{'switch'}{'value'};
    my $port = $p_ref->{'port'}{'value'};
    my $tag = $p_ref->{'tag'}{'value'};

    my $tag_avail = $self->vce->is_tag_avaiable( username => $user, workgroup => $workgroup, switch => $switch, port => $port, tag => $tag);
    return $tag_avail;
}


1;
