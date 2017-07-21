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
has network_model_file => (is => 'rwp', default => '/var/run/vce/network_model.json');
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

    $self->_set_switch( GRNOC::RabbitMQ::Client->new( user => $self->rabbit_mq->{'user'},
						      pass => $self->rabbit_mq->{'pass'},
						      host => $self->rabbit_mq->{'host'},
						      timeout => 30,
						      port => $self->rabbit_mq->{'port'},
						      exchange => 'VCE',
						      topic => 'VCE.Switch.RPC' ));

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

    my $vlan_id = $self->vce->provision_vlan(
        workgroup => $workgroup,
        description => $description,
        username => $user,
        switch => $switch,
        port => $ports,
        vlan => $vlan
    );
    if(!defined($vlan_id)){
        return {results => [{success => 0}], error => {msg => "Unable to add circuit to network model"}};
    }

    my $details = $self->vce->network_model->get_vlan_details( vlan_id => $vlan_id);
    my $status  = undef;

    foreach my $e (@{$details->{'endpoints'}}) {
        my $port   = $e->{'port'};
        my $switch = $switch;
        my $vlan   = $vlan;

        $status = $self->_send_vlan_add($port, $switch, $vlan);
        if (!$status) {
            last;
        }
    }

    if (!$status){
        $self->vce->network_model->delete_vlan(vlan_id => $vlan_id);
        return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => "Unable to add VLAN to device"}};
    }

    $self->_send_vlan_description($description, $switch, $vlan );
    return {results => [{success => 1, vlan_id => $vlan_id}]};
}


=head2 edit_vlan

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

    #verify user in workgroup
    if($self->vce->access->user_in_workgroup( username => $user,
                                              workgroup => $workgroup )){

        my $details = $self->vce->network_model->get_vlan_details( vlan_id => $vlan_id );

        if($details->{'workgroup'} ne $workgroup){
            return {results => [], error => {msg => "Workgroup $workgroup is not allowed to edit vlan $vlan_id"}};
        }

        #first validate new circuit before we remove the old!
        if(!$self->vce->validate_circuit( workgroup => $workgroup,
                                          description => $description,
                                          username => $user,
                                          switch => $switch,
                                          port => $ports,
                                          vlan => $vlan )){
            return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => "Circuit does not validate"}};
        }

        $details = $self->vce->network_model->get_vlan_details( vlan_id => $vlan_id);
        my $status = undef;
        foreach my $e (@{$details->{'endpoints'}}) {
            my $port   = $e->{'port'};
            $status = $self->_send_vlan_remove( $port, $switch, $details->{'vlan'} );
        }
        
        if(!$status){
            return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => "Unable to remove VLAN from device"}};
        }else{
            
            $self->vce->delete_vlan( vlan_id => $vlan_id, workgroup => $workgroup );
            
            $self->vce->provision_vlan( vlan_id => $vlan_id,
                                        workgroup => $workgroup, 
                                        description => $description, 
                                        username => $user,  
                                        switch => $switch, 
                                        port => $ports, 
                                        vlan => $vlan);
            
            my $details = $self->vce->network_model->get_vlan_details( vlan_id => $vlan_id);
            my $status  = undef;
            foreach my $e (@{$details->{'endpoints'}}) {
                my $port   = $e->{'port'};
                
                $status = $self->_send_vlan_add( $port, $switch, $vlan );
            }

            if(!$status){
                return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => "Unable to add VLAN to device"}};
            }else{
                return {results => [{success => 1, vlan_id => $vlan_id}]};
            }
        }
    }else{
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }
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

    # Permissions check
    my $in_workgroup = $self->vce->access->user_in_workgroup(
        username  => $user,
        workgroup => $workgroup
    );
    if (!$in_workgroup) {
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }

    my $details = $self->vce->network_model->get_vlan_details( vlan_id => $vlan_id);
    if ($details->{'workgroup'} ne $workgroup) {
        return {results => [], error => {msg => "Workgroup $workgroup is not allowed to edit vlan $vlan_id"}};
    }

    # Do switch removal
    my $status = undef;
    my $switch = $details->{'switch'};
    my $vlan = $details->{'vlan'};

    foreach my $e (@{$details->{'endpoints'}}) {
        my $port   = $e->{'port'};

        $status = $self->_send_vlan_remove( $port, $switch, $vlan );
        if (!$status) {
            return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => "Unable to remove VLAN from device"}};
        }
    }

    $self->_send_no_vlan($switch, $vlan);

    $self->vce->network_model->delete_vlan( vlan_id => $vlan_id);
    return {results => [{success => 1}]};
}

sub _send_vlan_description{
    my $self   = shift;
    my $desc   = shift;
    my $switch = shift;
    my $vlan   = shift;
    $self->logger->info("Adding description $desc to vlan $vlan on $switch");

   my $response = $self->switch->vlan_description(description => $desc, vlan => $vlan);
   if (exists $response->{'results'}->{'error'}) {
       $self->logger->error($response->{'results'}->{'error'});
       return 0;
   }

    return 1;
}

sub _send_vlan_add{
    my $self   = shift;
    my $port   = shift;
    my $switch = shift;
    my $vlan   = shift;
    $self->logger->info("Adding vlan $vlan to port $port on $switch");

   my $response = $self->switch->interface_tagged(port => $port, vlan => $vlan);
   if (exists $response->{'results'}->{'error'}) {
       $self->logger->error($response->{'results'}->{'error'});
       return 0;
   }

    return 1;
}

sub _send_vlan_remove{
    my $self   = shift;
    my $port   = shift;
    my $switch = shift;
    my $vlan   = shift;
    $self->logger->info("Removing vlan $vlan from port $port on $switch");

    my $response = $self->switch->no_interface_tagged(port => $port, vlan => $vlan);
    if (exists $response->{'results'}->{'error'}) {
        $self->logger->error($response->{'results'}->{'error'});
        return 0;
    }

    return 1;
}

sub _send_no_vlan {
    my $self   = shift;
    my $switch = shift;
    my $vlan   = shift;
    $self->logger->info("Removing vlan $vlan from $switch");

    my $response = $self->switch->no_vlan(vlan => $vlan);
    if (exists $response->{'results'}->{'error'}) {
        $self->logger->error($response->{'results'}->{'error'});
        return 0;
    }

    return 1;
}

1;
