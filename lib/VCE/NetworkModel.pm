#!/usr/bin/perl

package VCE::NetworkModel;

use strict;
use warnings;

use JSON::XS;
use GRNOC::Log;

use Data::UUID;

use constant NET_MODEL => "/var/run/vce/network_model.json";

has logger => (is => 'rwp');
has nm => (is => 'rwp');
has uudi => (is => 'rwp');

=head2 BUILD

creates a new NetworkModel object

=cut

sub BUILD{
    my ($self) = @_;
    
    my $logger = GRNOC::Log->get_logger("VCE::NetworkModel");
    $self->_set_logger($logger);

    $self->_set_uuid( new Data::UUID );

    $self->_read_network_model();

    return $self;
}

sub _read_network_model{
    my $self = shift;

    if(!-e NET_MODEL){
	
	$self->_set_nm({vlans => []});
	$self->_write_network_model();

    }else{
	my $str;
	open(my $fh, "<", NET_MODEL);
	while(my $line = <$fh>){
	    $str .= $line;
	}
	my $data = from_json($str);
	$self->_set_nm($data);
    }
}

sub _write_network_model{
    my $self = shift;

    my $json = to_json($self->nm);
    open(my $fh, ">", NET_MODEL);
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

    my $obj = {};
    $obj->{'vlan_id'} = $self->uuid->to_string($self->uuid->create());
    $obj->{'description'} = $params{'description'};
    $obj->{'workgroup'} = $params{'workgroup'};
    $obj->{'username'} = $params{'username'};
    $obj->{'create_time'} = time();
    $obj->{'endpoints'} = [];
    $obj->{'status'} = "Active";
    

    foreach my $ep (@{$params{'endpoints'}}){
	my $ep_obj = {};
	$ep_obj->{'port'} = $ep_obj->{'port'};
	$ep_obj->{'tag'} = $ep_obj->{'tag'};
	push(@{$obj->{'endpoints'}}, $ep_obj);
    }

    $self->nm->{'vlans'}->{$obj->{'vlan_id'}} = $obj;

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
	$self->logger->error("check_tag_availability: ");
    }
    
    if(!defined($params{'switch'})){
	
    }
    
    if(!defined($params{'port'})){
	
    }

    

}

=head2 delete_vlan

deletes a vlan from the network model

=cut

sub delete_vlan{
    my $self = shift;
    my %params = @_;

    if(defined($self->nm->{'vlans'}->{$params{'vlan_id'}})){
	$self->logger->debug("Removing VLAN: " . $params{'vlan_id'} . " from network model");
	delete $self->nm->{'vlanss'}->{$params{'vlan_id'}};
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
	foreach my $vlan (keys(%{$self->nm->{'vlans'}})){
	    if($vlan->{'workgroup'} eq $params{'workgroup'}){
		push(@vlans, $vlan);
	    }
	}
    }
    
    return \@vlans;
}



1;
