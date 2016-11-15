#!/usr/bin/perl

## Copyright 2011 Trustees of Indiana University
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

VCE::Access - Virtual Customer Equipment - Access module

=cut

package VCE::Access;

use strict;
use warnings;

use Moo;
use VCE;
use GRNOC::Log;
use Data::Dumper;

has config => (is => 'rwp');
has logger => (is => 'rwp');

=head2 BUILD

=cut

sub BUILD{
    my ($self) = @_;
    
    my $logger = GRNOC::Log->get_logger("VCE::Access");
    $self->_set_logger($logger);    

    return $self;
}

=head2 has_access

=cut

sub has_access{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'username'})){
        $self->logger->error("has_access: username not specified");
        return 0;
    }

    if(!defined($params{'workgroup'})){
        $self->logger->error("has_access: workgroup not specified");
        return 0;
    }

    if(!defined($params{'switch'})){
	$self->logger->error("has_access: switch not specified");
        return 0;
    }

    if(!defined($params{'port'})){
        $self->logger->error("has_access: port not specified");
        return 0;
    }

    return 0 if(!$self->user_in_workgroup( username => $params{'username'},
					   workgroup => $params{'workgroup'}));
    
    return 0 if(!$self->workgroup_has_access_to_port( workgroup => $params{'workgroup'},
						     switch => $params{'switch'},
						     port => $params{'port'},
						     vlan => $params{'vlan'}));
       
    $self->logger->debug("User " . $params{'username'} . " has access via workgroup " . $params{'workgroup'} . " has access to switch:port " . $params{'switch'} . ":" . $params{'port'});
    return 1;
}

=head2 user_in_workgroup

=cut

sub user_in_workgroup{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'username'})){
	$self->logger->error("user_in_workgroup: username not specified");
	return 0;
    }
    
    if(!defined($params{'workgroup'})){
	$self->logger->error("user_in_workgroup: workgroup not specified");
	return 0;
    }

    if(defined($self->config->{'workgroups'}->{$params{'workgroup'}})){
	foreach my $user (keys(%{$self->config->{'workgroups'}->{$params{'workgroup'}}->{'user'}})){
	    if($params{'username'} eq $user){
		$self->logger->error("user_in_workgroup: user " . $params{'username'} . " is in workgroup " . $params{'workgroup'});
		return 1;
	    }
	}
    }else{
	$self->logger->error("No workgroup " . $params{'workgroup'} . " in configuration");
	return 0;
    }

    $self->logger->error("user_in_workgroup: user " . $params{'username'} . " is not workgroup " . $params{'workgroup'});
    return 0;
}

=head2 workgroup_has_access_to_port

=cut

sub workgroup_has_access_to_port{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("workgroup_has_access_to_port: workgroup not specified");
        return 0;
    }

    if(!defined($params{'switch'})){
	$self->logger->error("workgroup_has_access_to_port: switch not specified");
	return 0;
    }

    if(!defined($params{'port'})){
        $self->logger->error("workgroup_has_access_to_port: port not specified");
        return 0;
    }
    
    if(defined($self->config->{'switches'}->{$params{'switch'}})){
	
	if(defined($self->config->{'switches'}->{$params{'switch'}}->{'ports'}->{$params{'port'}})){
	    
	    if(defined($params{'vlan'})){
		
		if(defined($self->config->{'switches'}->{$params{'switch'}}->{'ports'}->{$params{'port'}}->{'tags'}->{$params{'vlan'}})){
		    if($self->config->{'switches'}->{$params{'switch'}}->{'ports'}->{$params{'port'}}->{'tags'}->{$params{'vlan'}} eq $params{'workgroup'}){
			$self->logger->debug("workgroup_has_access_to_port: workgroup " . $params{'workgroup'} . " has access to " . $params{'switch'} . ":" . $params{'port'});
			return 1;
		    }else{
			$self->logger->debug("workgroup_has_access_to_port: workgroup " . $params{'workgroup'} . " does not have access to " . $params{'switch'} . ":" . $params{'port'});
			return 0;
		    }
		}

	    }else{
		
		foreach my $tag (keys(%{$self->config->{'switches'}->{$params{'switch'}}->{'ports'}->{$params{'port'}}->{'tags'}})){
		    if($self->config->{'switches'}->{$params{'switch'}}->{'ports'}->{$params{'port'}}->{'tags'}->{$tag} eq $params{'workgroup'}){
			$self->logger->debug("workgroup_has_access_to_port: workgroup " . $params{'workgroup'} . " has access to " . $params{'switch'} . ":" . $params{'port'});
			return 1;
		    }
		}
		$self->logger->debug("workgroup_has_access_to_port: workgroup " . $params{'workgroup'} . " does not have access to " . $params{'switch'} . ":" . $params{'port'});		
		return 0;
	    }

	}else{
	    $self->logger->debug("workgroup_has_access_to_port: No port on switch " . $params{'switch'} . " named " . $params{'port'} . " found in configuration");
	    return 0;
	}

    }else{
	$self->logger->debug("workgroup_has_access_to_port: No switch in configuration called " . $params{'switch'});
	return 0;
    }

    $self->logger->debug("workgroup_has_access_to_port: workgroup " . $params{'workgroup'} . " does not have access to " . $params{'switch'} . ":" . $params{'port'});

    return 0;
}

=head2 get_tags_on_port

=cut

sub get_tags_on_port{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("get_available_tags_on_port: workgroup not specified");
        return;
    }

    if(!defined($params{'switch'})){
        $self->logger->error("get_available_tags_on_port: switch not specified");
        return;
    }

    if(!defined($params{'port'})){
        $self->logger->error("get_available_tags_on_port: port not specified");
        return;
    }
    
    my @available_tags;
    for(my $vlan = 1; $vlan < 4095; $vlan++){
        if($self->workgroup_has_access_to_port( workgroup => $params{'workgroup'},
                                                switch => $params{'switch'},
                                                port => $params{'port'},
                                                vlan => $vlan)){
            push(@available_tags, $vlan);
        }
    }
    return \@available_tags;
    
}

=head2 get_workgroup_switches

=cut

sub get_workgroup_switches{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("get_workgroup_switches: workgroup not specified");
        return;
    }
    
    my %switches;

    foreach my $switch (keys (%{$self->config->{'switches'}})){
        foreach my $port (keys (%{$self->config->{'switches'}->{$switch}->{'ports'}})){
            if($self->workgroup_has_access_to_port( workgroup => $params{'workgroup'},
                                                    switch => $switch,
                                                    port => $port)){
                $switches{$switch} = 1;
                
            }
        }
    }
    my @switches = keys %switches;
    return \@switches;
}


1;
