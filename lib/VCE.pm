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

=head1 NAME

VCE - VCE Virtual Customer Equipement

=head1 VERSION

Version 1.0.0

=cut

our $VERSION = '1.0.0';

package VCE;

use strict;
use warnings;

use Moo;
use GRNOC::Log;
use GRNOC::Config;
use GRNOC::RabbitMQ;

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

=head1 SYNOPSIS
This is a module to provide a simplified object oriented way to connect to
and interact with the VCE database.

Some examples:

    use VCE;

    my $vce = VCE->new();
    my $is_in_workgroup = $vce->access->user_in_workgroup( username => 'aragusa@iu.edu',
                                                           workgroup => 'ajco');


=cut

=head2 BUILD



=cut

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE");
    $self->_set_logger($logger);
    
    $self->_process_config();

    $self->_set_access( VCE::Access->new( config => $self->config ));

    $self->_set_network_model( VCE::NetworkModel->new( file => $self->network_model_file ));
    
    return $self;
}

sub _process_config{
    my $self = shift;

    my $config = GRNOC::Config->new( config_file => $self->config_file, force_array => 1);
    
    my %workgroups;
    my %users;

    my $wgs = $config->get('/accessPolicy/workgroup');
    foreach my $workgroup (@$wgs){
	$self->logger->debug("Processing workgroup: " . Data::Dumper::Dumper($workgroup));
	my $grp = {};
	$grp->{'name'} = $workgroup->{'name'};
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
	$self->logger->debug("Processing switch: " . Data::Dumper::Dumper($switch));
	my $s = {};
	$s->{'name'} = $switch->{'name'};
	

	my %ports;
	foreach my $port (keys(%{$switch->{'port'}})){
	    my $p = {};
	    my %tags;
            
	    foreach my $tag (@{$switch->{'port'}->{$port}->{'tags'}}){
		for(my $i=$tag->{'start'};$i<=$tag->{'end'};$i++){
		    $tags{$i} = $tag->{'workgroup'};
		}
	    }
	    
	    $p->{'tags'} = \%tags;
	    $s->{'ports'}->{$port} = $p;
	    $p->{'owner'} = $switch->{'port'}->{$port}->{'owner'};
	}

	$switches{$switch->{'name'}} = $s;
	
	
    }

    $cfg->{'switches'} = \%switches;
    $self->_set_config($cfg);
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
    return $switches;
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
    
=cut

sub validate_circuit{
    my $self = shift;
    my %params = @_;
    
    
    
    if($#{$params{'port'}} < 1){
        $self->logger->error("Not enough endpoints");
        return;
    }
    
    my $vlan;
    
    #validate endpoints and create ep object
    for(my $i=0; $i <= $#{$params{'port'}}; $i++){
        
        $self->logger->error("Checking access to port");
        
        if(!$self->access->workgroup_has_access_to_port( workgroup => $params{'workgroup'},
                                                         switch => $params{'switch'},
                                                         port => $params{'port'}->[$i],
                                                         vlan => $params{'vlan'})){
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
    
    if($self->validate_circuit( %params )){

        my @eps;
        for(my $i=0; $i <= $#{$params{'port'}}; $i++){
            push(@eps,{ port => $params{'port'}->[$i]});
        }
        
        $self->logger->error("Provisioning VLAN in network model");
        
        #ok we made it this far... provision!
        my $id = $self->network_model->add_vlan( description => $params{'description'},
                                                 workgroup => $params{'workgroup'},
                                                 vlan => $params{'vlan'},
                                                 switch => $params{'switch'},
                                                 endpoints => \@eps,
                                                 username => $params{'username'});
        return $id;
    }
    
    return;
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

=head2 refresh_state

=cut

sub refresh_state{
    my $self = shift;
    my %params = @_;
    
    $self->network_model->reload_state();


}


1;
