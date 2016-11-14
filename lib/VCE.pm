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


has config_file => (is => 'rwp', default => "/etc/vce/access_policy.xml");
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

    $self->_set_network_model( VCE::NetworkModel->new( ));
    
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

=head2 get_available_tags_on_port

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


sub is_tag_available{
    my $self = shift;
    my %params = @_;
    
    
    if(!defined($params{'switch'})){
        $self->logger->error("is_tag_available: Switch not specified");
        return;
    }

    if(!defined($params{'port'})){
        $self->logger->error("is_tag_available: Port not specified");
        return;
    }

    if(!defined($params{'tag'})){
        $self->logger->error("is_tag_available: tag not specified");
        return;
    }

    return $self->network_model->check_tag_availability( switch => $params{'switch'},
                                                         port => $params{'port'},
                                                         tag => $params{'tag'});
    
}


1;
