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
has network_model_file => (is => 'rwp', default => '/var/lib/vce/network_model.sqlite');

has rabbit_mq => (is => 'rwp');

=head2 BUILD

=over 4

=item vce

=item logger

=item dispatcher

=item config_file

=item network_model_file

=item rabbit_mq

=back

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
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");

    $d->register_method($method);

    $method = GRNOC::WebService::Method->new( name => "get_interfaces_operational_status",
                                              description => "returns a list of interfaces available to a user",
                                              callback => sub{ return $self->get_interfaces_operational_status(@_) });
    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");
    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Switch name");
    $d->register_method($method);
}

=head2 handle_request

=cut

sub handle_request{
    my $self = shift;

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
        my $err = "User $user is not in workgroup " . $workgroup;
        $self->logger->error($err);
        return {results => [], error => {msg => $err}};
    }

}

=head2 get_interfaces_operational_status

=cut

sub get_interfaces_operational_status {
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $switch = $p_ref->{'switch'}{'value'};
    $self->logger->info("Calling get_interfaces_operational_status");

    #verify user in workgroup
    if (!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup)) {
        my $err = "User $user not in specified workgroup $workgroup";
        $self->logger->error($err);
        return {results => [], error => {msg => $err}};
    }

    my $ports = $self->vce->get_available_ports(
        workgroup => $workgroup,
        switch => $switch,
        ports => undef
    );

    my $port_info = $self->vce->get_interfaces_operational_state(
        workgroup => $workgroup,
        switch => $switch
    );
    if (!defined $port_info) {
        my $err = "Could not get interface state from device.";
        $self->logger->error($err);
        return {results => [], error => {msg => $err}};
    }

    my $result = [];
    foreach my $port (@{$ports}) {
        my $pdata = $port_info->{$port->{'port'}};
        $pdata->{'tags'} = $self->vce->access->friendly_display_vlans($port->{'tags'});
        push(@{$result}, $pdata);
    }

	return {results => [{ ports => $result}]};
}

1;
