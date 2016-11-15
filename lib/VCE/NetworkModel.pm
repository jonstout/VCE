#!/usr/bin/perl

package VCE::NetworkModel;

use strict;
use warnings;

use Moo;
use JSON::XS;
use GRNOC::Log;

use Data::UUID;

has logger => (is => 'rwp');
has file => (is => 'rwp');
has nm => (is => 'rwp', default => '/var/run/vce/network_model.json' );
has uuid => (is => 'rwp');

=head2 BUILD

creates a new NetworkModel object

=cut

sub BUILD{
    my ($self) = @_;
    
    my $logger = GRNOC::Log->get_logger("VCE::NetworkModel");
    $self->_set_logger($logger);

    $self->_set_uuid( Data::UUID->new() );

    $self->_read_network_model();

    return $self;
}

sub _read_network_model{
    my $self = shift;

    if(!-e $self->file ){
	
	$self->_set_nm({vlans => {}});
	$self->_write_network_model();

    }else{
	my $str;
	open(my $fh, "<", $self->file);
	while(my $line = <$fh>){
	    $str .= $line;
	}
	my $data = decode_json($str);
	$self->_set_nm($data);
    }
}

sub _write_network_model{
    my $self = shift;

    my $json = encode_json($self->nm);
    open(my $fh, ">", $self->file);
    print $fh $json;
    close($fh);
    
}

=head2 add_vlan

adds a vlan to the networkand creates a uuid ID for the vlan

returns the uuid for the vlan

=cut

sub add_vlan{
    my $self = shift;
    my %params = @_;

    $self->logger->error("Adding a VLAN");

    my $obj = {};
    if(!defined($params{'vlan_id'})){
        $obj->{'vlan_id'} = $self->uuid->to_string($self->uuid->create());
    }else{
        if(defined($self->nm->{'vlans'}->{$params{'vlan_id'}})){
            $self->logger->error("Add VLAN: with vlan id already existing");
            return;
        }
        $obj->{'vlan_id'} = $params{'vlan_id'};
    }
    $obj->{'description'} = $params{'description'};
    $obj->{'workgroup'} = $params{'workgroup'};
    $obj->{'username'} = $params{'username'};
    $obj->{'create_time'} = time();
    $obj->{'endpoints'} = [];
    $obj->{'status'} = "Active";
    
    $self->logger->error("All base parts ready");

    foreach my $ep (@{$params{'endpoints'}}){
        #validate that the endpoint is not in use!
        
        if($self->check_tag_availability( switch => $ep->{'switch'},
                                          port => $ep->{'port'},
                                          tag => $ep->{'vlan'})){
            
            my $ep_obj = {};
            $ep_obj->{'switch'} = $ep->{'switch'};
            $ep_obj->{'port'} = $ep->{'port'};
            $ep_obj->{'tag'} = $ep->{'vlan'};

            push(@{$obj->{'endpoints'}}, $ep_obj);
        }else{
            $self->logger->error("Endpoint " . $ep->{'switch'} . ":" . $ep->{'port'} . " tag " . $ep->{'vlan'} . " is already in use");
            return;
        }
    }

    $self->logger->error("processed endpoints");

    $self->nm->{'vlans'}->{$obj->{'vlan_id'}} = $obj;

    $self->logger->error("Writing network model");

    $self->_write_network_model();

    return $obj->{'vlan_id'};
}

=head2 check_tag_availability

this looks only at the network model to verify
that this vlan is not used in VCE

it does not verify that the user/workgroup has access
or that the vlan isn't already configured on the given
port

=cut

sub check_tag_availability{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'tag'})){
	$self->logger->error("check_tag_availability: tag not defined");
        return;
    }
    
    if(!defined($params{'switch'})){
        $self->logger->error("check_tag_availability: switch not defined");
        return;
    }
    
    if(!defined($params{'port'})){
        $self->logger->error("check_tag_availability: port not defined");
        return;
    }

    foreach my $vlan (keys (%{$self->nm->{'vlans'}})){
        foreach my $ep (@{$self->nm->{'vlans'}->{$vlan}->{'endpoints'}}){
            if($ep->{'switch'} eq $params{'switch'} && $ep->{'port'} eq $params{'port'} && $ep->{'tag'} eq $params{'tag'}){
                #no it is not available in use by this vlan
                return 0;
            }
        }
    }

    #yep its available

    return 1;
}

=head2 delete_vlan

deletes a vlan from the network model

=cut

sub delete_vlan{
    my $self = shift;
    my %params = @_;

    if(defined($self->nm->{'vlans'}->{$params{'vlan_id'}})){
	$self->logger->debug("Removing VLAN: " . $params{'vlan_id'} . " from network model");
	delete $self->nm->{'vlans'}->{$params{'vlan_id'}};
	$self->_write_network_model();
	return 1;
    }else{
	$self->logger->error("No vlan " . $params{'vlan_id'} . " found in network model");
	return;
    }
}

=head2 get_vlans

    returns a list of vlans if specified a list of vlans for a workgroup

=cut

sub get_vlans{
    my $self = shift;
    my %params = @_;

    my @vlans;

    if(!defined($params{'workgroup'})){
	foreach my $vlan (keys(%{$self->nm->{'vlans'}})){
	    push(@vlans, $vlan);
	}
    }else{
	foreach my $vlan_id (keys(%{$self->nm->{'vlans'}})){
            my $vlan = $self->nm->{'vlans'}->{$vlan_id};
	    if($vlan->{'workgroup'} eq $params{'workgroup'}){
		push(@vlans, $vlan_id);
	    }
	}
    }
    
    return \@vlans;
}

=head2 get_vlan_details

=cut

sub get_vlan_details{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'vlan_id'})){
        $self->logger->error("No VLAN ID specified");
        return;
    }

    if(defined($self->nm->{'vlans'}->{$params{'vlan_id'}})){
        return $self->nm->{'vlans'}->{$params{'vlan_id'}};
    }

    $self->logger->error("No VLAN with ID: " . $params{'vlan_id'});
    return;
}

1;
