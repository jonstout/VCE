#!/usr/bin/perl

package VCE::Services::Provisioning;

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

    my $logger = GRNOC::Log->get_logger("VCE::Services::Provisioning");
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

    my $method = GRNOC::WebService::Method->new( name => "add_vlan",
                                                 description => "provisions a vlan",
                                                 callback => sub{ return $self->provision_vlan(@_) });
    
    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");
    
    $method->add_input_parameter( name => "description",
                                  pattern => $GRNOC::WebService::Regex::TEXT,
                                  required => 1,
                                  multiple => 0,
                                  description => "VLAN Description for humans to see");

    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 1,
                                  multiple => 1,
                                  description => "Switch for the port to provision on");

    $method->add_input_parameter( name => "port",
                                  pattern => "(.*)",
                                  required => 1,
                                  multiple => 1,
                                  description => "Individual name of a port to provision on");

    $method->add_input_parameter( name => "tag",
                                  pattern => $GRNOC::WebService::Regex::NUMBER,
                                  required => 1,
                                  multiple => 1,
                                  description => "VLAN Tag to provision on");

    $d->register_method($method);    

    $method = GRNOC::WebService::Method->new( name => "edit_vlan",
                                              description => "edits a vlan",
                                              callback => sub{ return $self->edit_vlan(@_) });
    
    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");

    $method->add_input_parameter( name => "description",
                                  pattern => $GRNOC::WebService::Regex::TEXT,
                                  required => 1,
                                  multiple => 0,
                                  description => "VLAN Description for humans to see");

    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 1,
                                  multiple => 1,
                                  description => "Switch for the port to provision on");

    $method->add_input_parameter( name => "port",
                                  pattern => "(.*)",
                                  required => 1,
                                  multiple => 1,
                                  description => "Individual name of a port to provision on");

    $method->add_input_parameter( name => "tag",
                                  pattern => $GRNOC::WebService::Regex::NUMBER,
                                  required => 1,
                                  multiple => 1,
                                  description => "VLAN Tag to provision on");

    $method->add_input_parameter( name => "vlan_id",
                                  pattern => $GRNOC::WebService::Regex::TEXT,
                                  required => 1,
                                  multiple => 1,
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
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");

    $d->register_method($method);

}

sub handle_request{
    my $self = shift;

    $self->dispatcher->handle_request();
}


sub provision_vlan{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    #my $user = $ENV{'REMOTE_USER'};
    my $user = "aragusa";
    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $switches = $p_ref->{'switch'}{'value'};
    my $ports = $p_ref->{'port'}{'value'};
    my $tags = $p_ref->{'tag'}{'value'};
    my $description = $p_ref->{'description'}{'value'};

    #verify user in workgroup
    if($self->vce->access->user_in_workgroup( username => $user,
                                              workgroup => $workgroup )){

        my $vlan_id = $self->vce->provision_vlan( workgroup => $workgroup, description => $description, username => $user,  switch => $switches, port => $ports, tag => $tags);
        if(!defined($vlan_id)){
            return {results => [{success => 0}], error => {msg => "Unable to add circuit to network model"}};
        }
        
        my $status = $self->send_vlan_add( vlan_id => $vlan_id );                                        
        
        if($status){
            
            return {results => [{success => 1, vlan_id => $vlan_id}]};
        }else{
            return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => "Unable to add VLAN to device"}};
        }
    }else{
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }
}


1;

sub edit_vlan{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $switches = $p_ref->{'switch'}{'value'};
    my $ports = $p_ref->{'port'}{'value'};
    my $tags = $p_ref->{'tag'}{'value'};
    my $description = $p_ref->{'description'}{'value'};
    my $vlan_id = $p_ref->{'vlan_id'}{'value'};

    #verify user in workgroup
    if($self->vce->access->user_in_workgroup( username => $user,
                                              workgroup => $workgroup )){

        my $details = $self->vce->network_model->get_vlan_details( vlan_id => $vlan_id );

        if($details->{'workgroup'} ne $workgroup){
            return {results => [], error => {msg => "Workgroup $workgroup is not allowed to edit vlan $vlan_id"}};
        }

        my $status = $self->send_vlan_remove( vlan_id => $vlan_id);
        
        if(!$status){
            return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => "Unable to remove VLAN from device"}};
        }else{
            
            $self->vce->delete_vlan( vlan_id => $vlan_id );
            
            $self->vce->provision_vlan( vlan_id => $vlan_id,
                                        workgroup => $workgroup, 
                                        description => $description, 
                                        username => $user,  
                                        switch => $switches, 
                                        port => $ports, 
                                        tag => $tags);
            
            $status = $self->send_vlan_add( vlan_id => $vlan_id);

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

sub delete_vlan{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $vlan_id = $p_ref->{'vlan_id'}{'value'};

    #verify user in workgroup
    if($self->vce->access->user_in_workgroup( username => $user,
                                              workgroup => $workgroup )){
        
        my $details = $self->vce->network_model->get_vlan_details( vlan_id => $vlan_id);
        if($details->{'workgroup'} eq $workgroup){
            my $status = $self->send_vlan_remove( vlan_id => $vlan_id);
            if(!$status){
                return {results => [{success => 0, vlan_id => $vlan_id}], error => {msg => "Unable to remove VLAN from device"}};
            }else{
                $self->vce->network_model->delete_vlan( vlan_id => $vlan_id);
                return {results => [{success => 1}]};
            }
        }else{
            return {results => [], error => {msg => "Workgroup $workgroup is not allowed to edit vlan $vlan_id"}};
        }
    }else{
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }
}


sub send_vlan_add{
    my $self = shift;

    return 1;
}

sub send_vlan_remove{
    my $self = shift;
    
    return 1;
}
