#!/usr/bin/perl

package VCE::Services::Provisioning;

use strict;
use warnings;

use Moo;

use VCE;

use GRNOC::Log;
use GRNOC::RabbitMQ::Client;
use GRNOC::WebService::Dispatcher;
use GRNOC::WebService::Method;
use GRNOC::WebService::Regex;

use Data::Dumper;

has vce=> (is => 'rwp');
has logger => (is => 'rwp');
has dispatcher => (is => 'rwp');
has switch => (is => 'rwp');

has config_file => (is => 'rwp', default => '/etc/vce/access_policy.xml');
has network_model_file => (is => 'rwp', default => '/var/lib/vce/network_model.sqlite');
has rabbit_mq => (is => 'rwp');

=head2 BUILD

=over 4

=item vce

=item logger

=item dispatcher

=item network_model_file

=item rabbit_mq

=item switch

=item config_file

=back

=cut

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE::Services::Provisioning");
    $self->_set_logger($logger);

    $self->_set_vce( VCE->new( config_file => $self->config_file,
                               network_model_file => $self->network_model_file  ) );

    $self->_set_switch(GRNOC::RabbitMQ::Client->new(
        user     => $self->rabbit_mq->{'user'},
        pass     => $self->rabbit_mq->{'pass'},
        host     => $self->rabbit_mq->{'host'},
        timeout  => 30,
        port     => $self->rabbit_mq->{'port'},
        exchange => 'VCE',
        topic    => 'VCE.Switch.'
    ));

    my $dispatcher = GRNOC::WebService::Dispatcher->new();

    $self->_register_webservice_methods($dispatcher);

    $self->_set_dispatcher($dispatcher);
    return $self;
}

sub _register_webservice_methods{
    my $self = shift;
    my $d = shift;

    my $method = GRNOC::WebService::Method->new( name => "add_vlan",
                                                 description => "provisions a vlan",
                                                 callback => sub{ return $self->provision_vlan(@_) });
    
    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");
    
    $method->add_input_parameter( name => "description",
                                  pattern => $GRNOC::WebService::Regex::TEXT,
                                  required => 1,
                                  multiple => 0,
                                  description => "VLAN Description for humans to see");

    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Switch for the port to provision on");

    $method->add_input_parameter( name => "port",
                                  pattern => "(.*)",
                                  required => 1,
                                  multiple => 1,
                                  description => "Individual name of a port to provision on");

    $method->add_input_parameter( name => "vlan",
                                  pattern => $GRNOC::WebService::Regex::NUMBER,
                                  required => 1,
                                  multiple => 0,
                                  description => "VLAN Tag to provision on");

    $d->register_method($method);    

    $method = GRNOC::WebService::Method->new( name => "edit_vlan",
                                              description => "edits a vlan",
                                              callback => sub{ return $self->edit_vlan(@_) });
    
    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");

    $method->add_input_parameter( name => "description",
                                  pattern => $GRNOC::WebService::Regex::TEXT,
                                  required => 1,
                                  multiple => 0,
                                  description => "VLAN Description for humans to see");

    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Switch for the port to provision on");

    $method->add_input_parameter( name => "port",
                                  pattern => "(.*)",
                                  required => 1,
                                  multiple => 1,
                                  description => "Individual name of a port to provision on");

    $method->add_input_parameter( name => "vlan",
                                  pattern => $GRNOC::WebService::Regex::NUMBER,
                                  required => 1,
                                  multiple => 0,
                                  description => "VLAN Tag to provision on");

    $method->add_input_parameter( name => "vlan_id",
                                  pattern => $GRNOC::WebService::Regex::TEXT,
                                  required => 1,
                                  multiple => 0,
                                  description => "VLAN ID to edit");

    $d->register_method($method);
    
    $method = GRNOC::WebService::Method->new( name => "delete_vlan",
                                              description => "delets a vlan",
                                              callback => sub{ return $self->delete_vlan(@_) });
    
    $method->add_input_parameter( name => "vlan_id",
                                  pattern => $GRNOC::WebService::Regex::TEXT,
                                  required => 1,
                                  multiple => 0,
                                  description => "VLAN ID to edit");

    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");

    $d->register_method($method);

}

=head2 handle_request

=cut
sub handle_request{
    my $self = shift;

    $self->dispatcher->handle_request();
}

=head2 provision_vlan

=cut
sub provision_vlan{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $switch = $p_ref->{'switch'}{'value'};
    my $ports = $p_ref->{'port'}{'value'};
    my $vlan = $p_ref->{'vlan'}{'value'};
    my $description = $p_ref->{'description'}{'value'};

    my $has_access = $self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup);
    if (!$has_access) {
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }

    my ($ok, $error) = $self->vce->access->is_vlan_permittee($workgroup, $switch, $ports, $vlan);
    if (!$ok) {
        $self->logger->error($error);
        return {results => [], error => {msg => $error}};
    }

    my $prov_vlan_res = $self->vce->provision_vlan(
        workgroup => $workgroup,
        description => $description,
        username => $user,
        switch => $switch,
        port => $ports,
        vlan => $vlan
    );
    if (defined $prov_vlan_res->{error}) {
        return {results => [{success => 0}], error => {msg => $prov_vlan_res->{error}}};
    }
    my $vlan_id = $prov_vlan_res->{vlan_id};

    my $details = $self->vce->network_model->get_vlan_details(vlan_id => $vlan_id);
    my $endpoints = [];
    my $endpoint_count = 0;

    foreach my $e (@{$details->{'endpoints'}}) {
        push(@{$endpoints}, $e->{'port'});
        $endpoint_count++;
    }

    $self->switch->{topic} = 'VCE.Switch.' . $switch;

    my $response = $self->switch->interface_tagged(
        port      => $endpoints,
        vlan      => $vlan,
        vlan_name => $details->{name}
    );
    if (defined $response->{'error'}) {
        $self->logger->error($response->{'error'});

        $self->vce->network_model->delete_vlan(vlan_id => $vlan_id);
        return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => $response->{'error'}}};
    }

    # Multipoint VLANs should have spanning-tree enabled.
    my $response;
    if ($endpoint_count > 2) {
        $response = $self->switch->vlan_spanning_tree(vlan => $vlan);
    } else {
        $response = $self->switch->no_vlan_spanning_tree(vlan => $vlan);
    }
    my $warning='';
    if (defined $response->{'error'}) {
	$warning = $response->{'error'};
        $self->logger->warn($response->{'error'});
    }

    $self->_send_vlan_description($description, $switch, $vlan, $details->{name});
    return {msg => $warning, results => [{success => 1, vlan_id => $vlan_id}]};
}

=head2 edit_vlan

There are two cases when a VLAN may be edited. The first requires that
the VLAN is owned by $workgroup and that the workgroup has been
allocated the appropriate VLANs on all of $ports.

The second case is when a port owner decides a VLAN should be removed
from its port. This case requires the ports being removed are owned by
$workgroup, and that no other ports are added.

=cut
sub edit_vlan{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $switch = $p_ref->{'switch'}{'value'};
    my $ports = $p_ref->{'port'}{'value'};
    my $vlan = $p_ref->{'vlan'}{'value'};
    my $description = $p_ref->{'description'}{'value'};
    my $vlan_id = $p_ref->{'vlan_id'}{'value'};

    my $valid_user = $self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup);
    if (!$valid_user) {
        my $error = "User $user not in specified workgroup $workgroup.";
        $self->logger->error($error);
        return {results => [], error => {msg => $error}};
    }

    my $details  = $self->vce->network_model->get_vlan_details( vlan_id => $vlan_id );
    if (!defined $details) {
        my $err = "Could't find vlan $vlan_id.";
        return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => $err}};
    }
    if ($vlan != $details->{'vlan'}) {
        my $err = 'Unable to change VLAN via edit. Please create a new VLAN.';
        $self->logger->error($err);
        return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => $err}};
    }

    my $is_admin = ($self->vce->access->get_admin_workgroup()->{name} eq $workgroup) ? 1 : 0;
    my $is_owner = $details->{'workgroup'} eq $workgroup;

    my $new_interfaces = []; # Interfaces to be added
    my $old_interfaces = []; # Interfaces to be removed

    my $ok  = undef;
    my $err = undef;

    # Port tracker. Begin by adding all ports to tracker with value of
    # zero. This 'zero' means that the port is not to be included in
    # the VLAN.
    my $total_ports = {};
    foreach my $endpoint (@{$details->{endpoints}}) {
        $total_ports->{$endpoint->{port}} = 0;
    }

    foreach my $port (@{$ports}) {
        if (!defined $total_ports->{$port}) {
            $total_ports->{$port} = 1;
            push @$new_interfaces, $port;
        } else {
            $total_ports->{$port} = 1;
        }
    }
    ($ok, $err) = $self->vce->access->is_vlan_permittee($workgroup, $switch, $new_interfaces, $vlan);
    if (defined $err) {
        $self->logger->error($err);
        return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => $err}};
    }

    foreach my $port (keys %$total_ports) {
        if ($total_ports->{$port} == 0) {
            delete $total_ports->{$port};
            push @$old_interfaces, $port;
        }
    }

    ($ok, $err) = $self->vce->access->is_vlan_permittee($workgroup, $switch, $old_interfaces, $vlan);
    if (defined $err) {
        $self->logger->error($err);
        return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => $err}};
    }

    $self->switch->{topic} = 'VCE.Switch.' . $switch;
    my $response = $self->switch->no_interface_tagged(
        port => $old_interfaces,
        vlan => $vlan,
        vlan_name => $details->{name}
    );
    if (defined $response->{'error'}) {
        $self->logger->error($response->{'error'});
        return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => $response->{'error'}}};
    }

    $self->vce->delete_vlan(vlan_id => $vlan_id, workgroup => $workgroup);

    my @new_ports = keys %$total_ports;

    my $new_vlan = $self->vce->provision_vlan(
        vlan_id => $vlan_id,
        workgroup => $workgroup,
        name => $details->{name},
        description => $description,
        username => $user,
        switch => $switch,
        port => \@new_ports,
        vlan => $vlan
    );
    $vlan_id = $new_vlan->{vlan_id};

    my $details = $self->vce->network_model->get_vlan_details(vlan_id => $vlan_id);
    if (!defined $details) {
        my $err = "Could't find vlan $vlan_id.";
        return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => $err}};
    }

    my $endpoint_count = @new_ports;

    my $response = $self->switch->interface_tagged(port => \@new_ports, vlan => $vlan, vlan_name => $details->{name});
    if (defined $response->{'error'}) {
        $self->logger->error($response->{'error'});
        return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => $response->{'error'}}};
    }

    # Multipoint VLANs should have spanning-tree enabled.
    my $response;
    if ($endpoint_count > 2) {
        $response = $self->switch->vlan_spanning_tree(vlan => $vlan);
    } else {
        $response = $self->switch->no_vlan_spanning_tree(vlan => $vlan);
    }
    my $warning='';
    if (defined $response->{'error'}) {
        $warning = $response->{'error'};
        $self->logger->warn($response->{'error'});
    }

    $self->_send_vlan_description($description, $switch, $vlan );
    return {msg => $warning, results => [{success => 1, vlan_id => $vlan_id}]};
}

=head2 delete_vlan

=cut
sub delete_vlan{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $vlan_id = $p_ref->{'vlan_id'}{'value'};

    my $in_workgroup = $self->vce->access->user_in_workgroup(username  => $user, workgroup => $workgroup);
    if (!$in_workgroup) {
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }

    # Check if is_vlan_owner
    my $is_admin = ($self->vce->access->get_admin_workgroup()->{name} eq $workgroup) ? 1 : 0;
    my $details = $self->vce->network_model->get_vlan_details(vlan_id => $vlan_id);

    if ($details->{'workgroup'} ne $workgroup && !$is_admin) {
        return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => "Workgroup $workgroup is not authorized to delete vlan $vlan_id."}};
    }

    # Do switch removal
    my $switch = $details->{'switch'};
    my $vlan = $details->{'vlan'};
    my $vlan_name = $details->{'name'};

    my $endpoints = [];
    foreach my $e (@{$details->{'endpoints'}}) {
        push(@{$endpoints}, $e->{'port'});
    }

    $self->switch->{topic} = 'VCE.Switch.' . $switch;
    my $response = $self->switch->no_interface_tagged(
        port => $endpoints,
        vlan => $vlan,
        vlan_name => $vlan_name
    );
    if (defined $response->{'error'}) {
        $self->logger->error($response->{'error'});
        return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => $response->{'error'}}};
    }

    $self->_send_no_vlan($switch, $vlan, $vlan_name);

    $self->vce->network_model->delete_vlan(vlan_id => $vlan_id);
    return {results => [{success => 1}]};
}

sub _send_vlan_description{
    my $self   = shift;
    my $desc   = shift;
    my $switch = shift;
    my $vlan   = shift;
    my $vlan_name = shift;
    $self->logger->info("Adding description $desc to vlan $vlan on $switch");

    $self->switch->{topic} = 'VCE.Switch.' . $switch;
    my $response = $self->switch->vlan_description(description => $desc, vlan => $vlan, vlan_name => $vlan_name);
    if (exists $response->{'error'}) {
        $self->logger->error($response->{'error'});
        return 0;
    }

    return 1;
}

sub _send_no_vlan {
    my $self   = shift;
    my $switch = shift;
    my $vlan   = shift;
    my $vlan_name = shift;
    $self->logger->info("Removing vlan $vlan from $switch");

    $self->switch->{topic} = 'VCE.Switch.' . $switch;
    my $response = $self->switch->no_vlan(vlan => $vlan, vlan_name => $vlan_name);
    if (exists $response->{'error'}) {
        $self->logger->error($response->{'error'});
        return 0;
    }

    return 1;
}

1;
