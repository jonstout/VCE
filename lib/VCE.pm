#!/usr/bin/perl

#----- VCE Virtual Customer Equipment
##----
##----
##---- Main module for interacting with the VCE application
##----
##
## Copyright 2016 Trustees of Indiana University
##
##   Licensed under the Apache License, Version 2.0 (the "License");
##  you may not use this file except in compliance with the License.
##   You may obtain a copy of the License at
##
##       http://www.apache.org/licenses/LICENSE-2.0
##
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.
#

=head1 VCE - VCE Virtual Customer Equipement

Version 0.2.3

=cut

our $VERSION = '0.2.3';

package VCE;

use strict;
use warnings;

use AnyEvent;
use Moo;
use GRNOC::Log;
use GRNOC::Config;
use GRNOC::RabbitMQ::Client;

use VCE::Access;
use VCE::NetworkModel;

use JSON::XS;
use Data::Dumper;

has config_file => (is => 'rwp', default => "/etc/vce/access_policy.xml");
has network_model_file => (is => 'rwp', default => "/var/run/vce/network_model.json");
has config => (is => 'rwp');
has logger => (is => 'rwp');

has access => (is => 'rwp');
has network_model => (is => 'rwp');

has state => (is => 'rwp');

has device_client => (is => 'rwp');

has rabbit_mq => (is => 'rwp');

=head1 SYNOPSIS

This is a module to provide a simplified object oriented way to connect to
and interact with the VCE database.

    use VCE;

    my $vce = VCE->new();
    my $is_in_workgroup = $vce->access->user_in_workgroup(
      username => 'aragusa@iu.edu',
      workgroup => 'ajco'
    );

=cut

=over 4

=item access

=item config

=item config_file

=item device_client

=item logger

=item network_model

=item network_model_file

=item rabbit_mq

=item state

=back 

=head2 BUILD

=cut

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE");
    $self->_set_logger($logger);
    
    $self->_process_config();

    $self->_set_access( VCE::Access->new( config => $self->config ));

    $self->_set_network_model( VCE::NetworkModel->new( file => $self->network_model_file ));

    $self->_set_device_client( GRNOC::RabbitMQ::Client->new( host => $self->rabbit_mq->{'host'},
                                                             port => $self->rabbit_mq->{'port'},
                                                             user => $self->rabbit_mq->{'user'},
                                                             pass => $self->rabbit_mq->{'pass'},
                                                             exchange => 'VCE',
                                                             topic => 'VCE.Switch.RPC'));

    $self->{'get_network_state_timer'} = AnyEvent->timer(
        after => 30,
        interval => 300,
        cb => sub { $self->_get_network_state() }
    );

    return $self;
}

sub _get_network_state {
    my $self = shift;

    $self->device_client->get_vlans( async_callback => sub {
        my $response = shift;
        if (defined $response->{'error'}) {
            return $self->logger->error($response->{'error'});
        }

        foreach my $vlan_id (keys %{$response->{'results'}}) {
            my $vlan = $self->network_model->get_vlan_details_by_number(number => $vlan_id);
            if (!defined $vlan) {
                my $switch_name = (keys(%{$self->config->{'switches'}}))[0];
                my $workgroup = $self->access->get_admin_workgroup();
                my $user = (keys %{$workgroup->{'user'}})[0];

                my $id = $self->network_model->add_vlan(
                    description => $response->{'results'}->{$vlan_id}->{'name'},
                    workgroup => $workgroup->{'name'},
                    vlan => $response->{'results'}->{$vlan_id}->{'vlan'},
                    switch => $switch_name,
                    endpoints => [],
                    username => $user
                );

                $vlan = $self->network_model->get_vlan_details(vlan_id => $id);
            }

            my $endpoints = [];
            foreach my $port (@{$response->{'results'}->{$vlan_id}->{'ports'}}) {
                $port->{'port'} =~ s/^\s+|\s+$//g;
                push(@{$endpoints}, { port => $port->{'port'} });
            }

            my $result = $self->network_model->set_vlan_endpoints(
                vlan_id => $vlan->{'vlan_id'},
                endpoints => $endpoints
            );
            $self->logger->debug('updated vlan: ' . Dumper($result));
        }
    });
}

sub _process_config{
    my $self = shift;

    my $config = GRNOC::Config->new(config_file => $self->config_file, force_array => 1, schema => '/etc/vce/config.xsd');
    if ($config->validate() != 1) {
        my $err = $config->get_error()->{'backtrace'}->{'message'};
        $self->logger->fatal('Configuration does not conform to schema: ' . $err);
        exit 1;
    }
    $self->logger->debug('Configuration validated.');

    my %workgroups;
    my %users;

    my $nm_model_file = $config->get('/accessPolicy/network_model');
    if(defined($nm_model_file) && defined($nm_model_file->[0])){
        $self->_set_network_model_file($config->get('/accessPolicy/network_model')->[0]->{'path'});
    }

    my $rabbitMQ = $config->get('/accessPolicy/rabbit')->[0];
    $self->_set_rabbit_mq($rabbitMQ);

    my $wgs = $config->get('/accessPolicy/workgroup');
    foreach my $workgroup (@$wgs){
	$self->logger->debug("Processing workgroup: " . Data::Dumper::Dumper($workgroup));
	my $grp = {};
	$grp->{'name'} = $workgroup->{'name'};
    $grp->{'admin'} = $workgroup->{'admin'};
	$grp->{'description'} = $workgroup->{'description'};
	$grp->{'user'} = $workgroup->{'user'};
	$workgroups{$grp->{'name'}} = $grp;
	foreach my $user (keys(%{$grp->{'user'}})){
	    if(!defined($users{$user})){
		$users{$user} = ();
	    }
	    push(@{$users{$user}},$grp->{'name'});
	}
    }
    
    my $cfg = {};
    $cfg->{'users'} = \%users;
    $cfg->{'workgroups'} = \%workgroups;
    
    my %switches;
    my $switches = $config->get('/accessPolicy/switch');
    foreach my $switch (@$switches){
	$self->logger->debug("Processing config for $switch->{'name'}");
	my $s = {};
	$s->{'name'} = $switch->{'name'};
	$s->{'description'} = $switch->{'description'};
        $s->{'ssh_port'} = $switch->{'ssh_port'};
        $s->{'vendor'} = $switch->{'vendor'};
        $s->{'model'} = $switch->{'model'};
        $s->{'version'} = $switch->{'version'};
        $s->{'username'} = $switch->{'username'};
        $s->{'password'} = $switch->{'password'};
        $s->{'ip'} = $switch->{'ip'};

	$s->{'commands'} = $self->_process_command_config($switch->{'commands'}->[0]);

	my %ports;
	foreach my $port (keys(%{$switch->{'port'}})){
	    my $p = {};
	    my %tags;
            
	    foreach my $tag (@{$switch->{'port'}->{$port}->{'tags'}}){
                warn Dumper($tag);
                for(my $i=$tag->{'start'};$i<=$tag->{'end'};$i++){
                    $tags{$i} = $tag->{'workgroup'};
                }
	    }
	    
	    $p->{'tags'} = \%tags;
	    $s->{'ports'}->{$port} = $p;
	    $p->{'owner'} = $switch->{'port'}->{$port}->{'owner'};
            $p->{'description'} = $switch->{'port'}->{$port}->{'description'};
        }

	$switches{$switch->{'name'}} = $s;
	
	
    }

    $cfg->{'switches'} = \%switches;
    $self->_set_config($cfg);
}

=head2 _process_command_config

=cut

sub _process_command_config{
    my $self = shift;
    my $config = shift;

    my $cfg = {};

    $self->logger->debug("Processing switch commands.");
    foreach my $type ("system","port","vlan"){
        my %commands = %{$config->{$type}->[0]->{'command'}};
        foreach my $cmd (keys(%commands)){
	    
            my $val = {name => $cmd,
                       method_name => $commands{$cmd}{'method_name'},
                       interaction => $commands{$cmd}{'interaction'},
                       actual_command => $commands{$cmd}{'cmd'}->[0],
                       type => $commands{$cmd}{'type'},
                       configure => $commands{$cmd}{'configure'},
                       params => $commands{$cmd}{'parameter'},
                       description => $commands{$cmd}{'description'},
                       context => $commands{$cmd}{'context'}};
	    
            if(!defined($val->{'configure'})){
                delete $val->{'configure'};
            }

            if(!defined($val->{'context'})){
                delete $val->{'context'};
            }
	    
            push(@{$cfg->{$type}},$val);

        }
    }

    return $cfg;
}

=head2 get_workgroups

=cut

sub get_workgroups{
    my $self = shift;

    my %params = @_;

    if(!defined($params{'username'})){
	my @wgps = (keys %{$self->config->{'workgroups'}});
	return \@wgps;
    }

    if(defined($self->config->{'users'}->{$params{'username'}})){
	return $self->config->{'users'}->{$params{'username'}};
    }

    
    return [];

}


=head2 get_available_ports

=cut

sub get_available_ports{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("get_available_ports: Workgroup not specified");
        return;
    }

    if(!defined($params{'switch'})){
        $self->logger->error("get_available_ports: Switch not specified");
        return;
    }

    my @ports;

    my $switch = $self->config->{'switches'}->{$params{'switch'}};
    foreach my $port (keys %{$switch->{'ports'}}){
        if($self->access->workgroup_has_access_to_port( workgroup => $params{'workgroup'},
                                                        switch => $params{'switch'},
                                                        port => $port)){

            my $tags = $self->access->get_tags_on_port(workgroup => $params{'workgroup'},
                                                       switch => $params{'switch'},
                                                       port => $port);

            push(@ports, {port => $port, tags => $tags});
        }
    }

    return \@ports;
}

=head2 get_tags_on_port

=cut

sub get_tags_on_port{
    my $self = shift;
    my %params = @_;
    
    if(!defined($params{'workgroup'})){
        $self->logger->error("get_tags_on_port: Workgroup not specified");
        return;
    }
    
    if(!defined($params{'switch'})){
        $self->logger->error("get_tags_on_port: Switch not specified");
        return;
    }

    if(!defined($params{'port'})){
        $self->logger->error("get_tags_on_port: Port not specified");
        return;
    }

    if($self->access->workgroup_has_access_to_port( workgroup => $params{'workgroup'},
                                                    switch => $params{'switch'},
                                                    port => $params{'port'})){
        return $self->access->get_tags_on_port(workgroup => $params{'workgroup'},
                                                         switch => $params{'switch'},
                                                         port => $params{'port'});
    }

}

=head2 get_switches

=cut

sub get_switches{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("get_tags_on_port: Workgroup not specified");
        return;
    }

    my $switches = $self->access->get_workgroup_switches( workgroup => $params{'workgroup'});

    my @res;
    foreach my $switch (@$switches){

        my $vlans = $self->network_model->get_vlans( workgroup => $params{'workgroup'},
                                                     switch => $switch);

        my $ports = $self->access->get_switch_ports( workgroup => $params{'workgroup'},
                                                     switch => $switch);
        push(@res,{ name => $switch,
                    description => $self->access->get_switch_description( switch => $switch),
                    vlans => $vlans,
                    ports => $ports});
    }

    return \@res;
}

=head2 get_interfaces_operational_state

=cut
sub get_interfaces_operational_state {
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("get_interfaces_operational_state: Workgroup not specified");
        return;
    }

    if(!defined($params{'switch'})){
        $self->logger->error("get_interfaces_operational_state: Switch not specified");
        return;
    }

    return $self->device_client->get_interfaces_op()->{'results'};
}

=head2 get_switches_operational_state

=cut

sub get_switches_operational_state{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("get_tags_on_port: Workgroup not specified");
        return;
    }

    my $switches = $self->get_switches( workgroup => $params{'workgroup'});
    foreach my $switch (@$switches){
        my %int_state;
        $switch->{'status'} = $self->_get_switch_status( switch => $switch );
        my $up_ports = 0;
        my @ports;
        foreach my $port (@{$switch->{'ports'}}){
            my $obj = {};
            $obj->{'name'} = $port;
            $obj->{'status'} = $self->_get_interface_status( switch => $switch,
                                                             interface => $port );
            $int_state{$port} = $obj->{'status'};
            if($obj->{'status'} eq 'Up'){
                $int_state{$port} = 1;
                $up_ports++;
            }else{
                $int_state{$port} = 0;
            }
            push(@ports,$obj);
        }
        $switch->{'up_ports'} = $up_ports;
        $switch->{'total_ports'} = scalar(@ports);
        $switch->{'ports'} = \@ports;
        my @vlans;
        my $up_vlans=0;
        foreach my $vlan (@{$switch->{'vlans'}}){
            my $is_up = 1;
            my $vlan = $self->network_model->get_vlan_details( vlan_id => $vlan );
            foreach my $interface (@{$vlan->{'endpoints'}}){
                if($int_state{$interface}){

                }else{
                    $is_up = 0;
                }
            }

            push(@vlans, { vlan => $vlan, status => $is_up, endpoints => $vlan->{'endpoints'}});

            if($is_up){
                $up_vlans++;
            }
        }
        $switch->{'up_vlans'} = $up_vlans;
        $switch->{'total_vlans'} = scalar(@vlans);
        $switch->{'vlans'} = \@vlans;
    }

    return $switches;
}

sub _get_switch_status{
    my $self = shift;
    my %params = @_;

    my $state = $self->device_client->get_device_status();
    if (defined $state->{'error'}) {
        $self->logger->error($state->{'error'});
        return 'Unknown';
    }

    if ($state->{'results'} == 1) {
        return 'Up';
    } elsif ($state->{'results'} == 0) {
        return 'Down';
    } else {
        return 'Unknown';
    }
}

sub _get_interface_status{
    my $self = shift;
    my %params = @_;

    my $state = $self->device_client->get_interface_status(interface => $params{'interface'});
    if (defined $state->{'error'}) {
        $self->logger->error($state->{'error'});
        return "Unknown";
    }

    if ($state->{'results'} == 1) {
        return 'Up';
    } elsif ($state->{'results'} == 0) {
        return 'Down';
    } else {
        return 'Unknown';
    }
}

=head2 is_tag_available

=cut

sub is_tag_available{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'switch'})){
        $self->logger->error("is_tag_available: Switch not specified");
        return;
    }

    if(!defined($params{'tag'})){
        $self->logger->error("is_tag_available: tag not specified");
        return;
    }

    return $self->network_model->check_tag_availability( switch => $params{'switch'},
                                                         vlan => $params{'tag'});
}

=head2 validate_circuit

    my $ok = validate_circuit(
      workgroup => $string,
      switch    => $string,
      port      => [$string],
      vlan      => $string,
    );

validate_circuit returns 1 if C<$workgroup> has access to all
C<($switch, $port, $vlan)> tuples. If the length of port is zero this
method returns C<undef>.

=cut
sub validate_circuit{
    my $self = shift;
    my %params = @_;

    my $port_count = $#{$params{'port'}} + 1;
    if ($port_count < 1) {
        $self->logger->error("Not enough endpoints. Got $port_count endpoints.");
        return;
    }

    for (my $i = 0; $i <= $#{$params{'port'}}; $i++) {
        my $has_access = $self->access->workgroup_has_access_to_port(
            workgroup => $params{'workgroup'},
            switch => $params{'switch'},
            port => $params{'port'}->[$i],
            vlan => $params{'vlan'}
        );
        if(!$has_access) {
            $self->logger->error("Workgroup " . $params{'workgroup'} . " does not have access to tag " . $params{'vlan'} . " on " . $params{'switch'} . ":" . $params{'port'}->[$i]);
            return;
        }
    }

    return 1;
}

=head2 provision_vlan

=cut
sub provision_vlan{
    my $self = shift;
    my %params = @_;

    warn 'provision_vlan: ' . Dumper(\%params);

    my $skip_validation = 0;
    if (defined $params{skip_validation}) {
        $skip_validation = $params{skip_validation};
    }

    my $valid_circuit = $self->validate_circuit(%params);
    warn Dumper(!$valid_circuit);
    warn Dumper(!$skip_validation);
    warn 'state: ' . Dumper(!$valid_circuit && $skip_validation == 0);

    if (!$valid_circuit && $skip_validation == 0) {
        warn "Could not validate the requested VLAN for provisioning.";
        $self->logger->error("Could not validate the requested VLAN for provisioning.");
        return;
    }

    warn "Adding VLAN to network model.";
    my $tag_available = $self->network_model->check_tag_availability(switch => $params{'switch'}, vlan => $params{'vlan'});
    if (!$tag_available) {
        $self->logger->error("VLAN " . $params{'vlan'} . " is invalid for the requested endpoints.");
        return;
    }

    my @eps;
    for (my $i=0; $i <= $#{$params{'port'}}; $i++) {
        push(@eps, {port => $params{'port'}->[$i]});
    }

    warn "Adding VLAN to network model.";
    $self->logger->info("Adding VLAN to network model.");

    warn "!!! adding vlan to the network model";
    return $self->network_model->add_vlan(
        description => $params{'description'},
        vlan_id => $params{'vlan_id'},
        workgroup => $params{'workgroup'},
        vlan => $params{'vlan'},
        switch => $params{'switch'},
        endpoints => \@eps,
        username => $params{'username'}
    );
}

=head2 delete_vlan

=cut

sub delete_vlan{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'}) || !defined($params{'vlan_id'})){
        $self->logger->error("Workgroup or VLAN ID not specified");
        return;
    }

    my $vlan = $self->network_model->get_vlan_details( vlan_id => $params{'vlan_id'});
    if(!defined($vlan)){
        $self->logger->error("No vlan by that Id can be found");
        return;
    }

    if($vlan->{'workgroup'} eq $params{'workgroup'}){
        $self->network_model->delete_vlan( vlan_id => $params{'vlan_id'} );
        return 1;
    }else{
        return 0;
    }

}

=head2 get_workgroup_details

get a workgroups details and return them

=cut

sub get_workgroup_details{
    my $self = shift;
    my %params = @_;
    
    if(!defined($params{'workgroup'})){
        $self->logger->error("get_workgroup_details: workgroup not specified");
        return;
    }

    my $workgroup = $params{'workgroup'};

    my $obj = {};
    $obj->{'name'} = $workgroup;
    $obj->{'description'} = $self->access->get_workgroup_description( workgroup => $workgroup);
    $obj->{'users'} = $self->access->get_workgroup_users( workgroup => $workgroup);
    $obj->{'switches'} = $self->access->get_workgroup_switches( workgroup => $workgroup);

    return $obj;
}

=head2 refresh_state

=cut

sub refresh_state{
    my $self = shift;
    my %params = @_;
    
    $self->network_model->reload_state();


}

=head2 get_all_switches

returns all configured switches (only used by the vce process to find all switches to created)

=cut

sub get_all_switches{
    my $self = shift;

    return $self->access->get_switches();
}

1;
