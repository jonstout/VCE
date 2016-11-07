#!/usr/bin/perl

package VCE::Access;

use strict;
use warnings;

use Moo;
use GRNOC::Log;

has config => (is => 'rwp');
has logger => (is => 'rwp');

sub BUILD{
    my ($self) = @_;
    
    my $logger = GRNOC::Log->get_logger("VCE::Access");
    $self->_set_logger($logger);    

    return $self;
}

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

    return 0 if ($self->user_in_workgroup( username => $params{'username'},
					   workgroup => $params{'workgroup'}));
    
    return 0 if($self->workgroup_has_access_to_port( workgroup => $params{'workgroup'},
						     switch => $params{'switch'},
						     port => $params{'port'}));
       
    $self->logger->debug("User " . $params{'username'} . " has access via workgroup " . $params{'workgroup'} . " has access to switch:port " . $params{'switch'} . ":" . $params{'port'});
    return 1;
}

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
	foreach my $user (@{$self->config->{'workgroups'}->{$params{'workgroup'}}->{'users'}}){
	    if($params{'username'} eq $user){
		$self->logger->debug("user_in_workgroup: user " . $params{'username'} . " is in workgroup " . $params{'workgroup'});
		return 1;
	    }
	}
    }else{
	$self->logger->error("No workgroup " . $params{'workgroup'} . " in configuration");
	return 0;
    }

    $self->logger->debug("user_in_workgroup: user " . $params{'username'} . " is not workgroup " . $params{'workgroup'});
    return 0;
}

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
	
	if(defined($self->config->{'switches'}->{$params{'switch'}}->{'port'}->{$params{'port'}})){
	    
	    if(defined($params{'vlan'})){
		
		if(defined($self->config->{'switches'}->{$params{'switch'}}->{'port'}->{$params{'port'}}->{'tags'}->{$params{'vlan'}})){
		    if($self->config->{'switches'}->{$params{'switch'}}->{'port'}->{$params{'port'}}->{'tags'}->{$params{'vlan'}}->{'workgroup'} eq $params{'workgroup'}){
			$self->logger->debug("workgroup_has_access_to_port: workgroup " . $params{'workgroup'} . " has access to " . $params{'switch'} . ":" . $params{'port'});
			return 1;
		    }else{
			$self->logger->debug("workgroup_has_access_to_port: workgroup " . $params{'workgroup'} . " does not have access to " . $params{'switch'} . ":" . $params{'port'});
			return 0;
		    }
		}

	    }else{
		
		foreach my $tag (keys(%{$self->config->{'switches'}->{$params{'switch'}}->{'port'}->{$params{'port'}}->{'tags'}})){
		    if($tag->{'workgroup'} eq $params{'workgroup'}){
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



1;
