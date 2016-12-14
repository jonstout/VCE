#!/usr/bin/perl

package VCE::Services::Operational;

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

has config_file => (is => 'rwp', default => '/etc/vce/access_policy.xml');
has network_model_file => (is => 'rwp', default => '/var/run/vce/network_model.json');

has rabbit_mq => (is => 'rwp');

=head2 BUILD

=cut

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE::Services::Operational");
    $self->_set_logger($logger);

    $self->_set_vce( VCE->new( config_file => $self->config_file,
                               network_model_file => $self->network_model_file,
                               rabbit_mq => $self->rabbit_mq  ) );

    my $dispatcher = GRNOC::WebService::Dispatcher->new();

    $self->_register_webservice_methods($dispatcher);

    $self->_set_dispatcher($dispatcher);

    return $self;
}

sub _register_webservice_methods{
    my $self = shift;
    my $d = shift;

    my $method = GRNOC::WebService::Method->new(
        name => "get_workgroup_operational_status",
        description => "returns a list of workgroups available to a user",
        callback => sub{ return $self->get_workgroup_operational_status(@_) });

    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");

    $d->register_method($method);

}

=head2 handle_request

=cut

sub handle_request{
    my $self = shift;

    $self->vce->refresh_state();

    $self->dispatcher->handle_request();
}


=head2 get_workgroup_operational_status

=cut

sub get_workgroup_operational_status{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};
    my $workgroup = $p_ref->{'workgroup'}{'value'};
    if($self->vce->access->user_in_workgroup( username => $user,
                                              workgroup => $workgroup )){
        
        $self->logger->debug("Fetching workgroups for user: " . $user);
        return {results => [{workgroups => $self->vce->get_switches_operational_state( workgroup => $workgroup )}]};
    }else{
        return {results => [], error => {msg => "User $user is not in workgroup " . $workgroup}};
    }

}

1;
