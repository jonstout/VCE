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

=over 4

=item logger

=item file

=item nm

=item uuid

=back

=cut

sub BUILD{
    my ($self) = @_;
    
    my $logger = GRNOC::Log->get_logger("VCE::NetworkModel");
    $self->_set_logger($logger);

    $self->_set_uuid( Data::UUID->new() );

    $self->_read_network_model();

    return $self;
}

=head2 reload_state

=cut
sub reload_state{
    my $self = shift;
    $self->_read_network_model();
}

=head2 _read_network_model

=cut
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
        if (!%{$data}) {
            $self->_set_nm({vlans => {}});
            $self->_write_network_model();
        } else {
            $self->_set_nm($data);
        }
    }
}

=head2 _write_network_model

=cut
sub _write_network_model{
    my $self = shift;

    my $json = encode_json($self->nm);
    open(my $fh, ">", $self->file) or die "Couldn't open: $!";
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

    return if(!defined($params{'switch'}));
    return if(!defined($params{'vlan'}));
    return if(!defined($params{'username'}));
    return if(!defined($params{'workgroup'}));
    return if(!defined($params{'endpoints'}));

    $obj->{'description'} = $params{'description'};
    $obj->{'workgroup'}   = $params{'workgroup'};
    $obj->{'username'}    = $params{'username'};
    $obj->{'switch'}      = $params{'switch'};
    $obj->{'vlan'}        = $params{'vlan'};
    $obj->{'create_time'} = time();
    $obj->{'endpoints'}   = [];
    $obj->{'status'} = "Active";

    if (!$self->check_tag_availability(switch => $obj->{'switch'}, vlan => $obj->{'vlan'})) {
        $self->logger->error("VLAN is already in use on switch");
        return;
    }

	$self->logger->info("Adding VLAN: " . $params{'vlan'} . " to network model.");

    foreach my $ep (@{$params{'endpoints'}}){
        my $ep_obj = {};
        $ep_obj->{'port'} = $ep->{'port'};
        push(@{$obj->{'endpoints'}}, $ep_obj);
    }

    $self->logger->debug("processed endpoints");
    
    $self->nm->{'vlans'}->{$obj->{'vlan_id'}} = $obj;
    
    $self->logger->debug("Writing network model");
    
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

    if (!defined $params{'vlan'}) {
        $self->logger->error("check_tag_availability: vlan not defined");
        return;
    }

    if (!defined $params{'switch'}) {
        $self->logger->error("check_tag_availability: switch not defined");
        return;
    }

    foreach my $vlan (keys %{$self->nm->{'vlans'}}) {
        my $v = $self->nm->{'vlans'}{$vlan};
        if ($v->{'switch'} eq $params{'switch'} && $v->{'vlan'} eq $params{'vlan'}) {
            return 0;
        }
    }

    return 1;
}

=head2 delete_vlan

deletes a vlan from the network model

=cut
sub delete_vlan{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'vlan_id'})){
        $self->logger->error("No vlan_id specified");
        return;
    }

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

    if (defined $params{'switch'}) {
        my @final;
        foreach my $vlan (@vlans){
            if($self->nm->{'vlans'}->{$vlan}->{'switch'} eq $params{'switch'}){
                push(@final, $vlan);
            }
        }
        return \@final;
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

=head2 get_vlan_details_by_number

=cut
sub get_vlan_details_by_number {
    my $self = shift;
    my %params = @_;

    if(!defined $params{'number'}) {
        $self->logger->error("No VLAN number specified.");
        return;
    }

    foreach my $vlan_id (keys %{$self->nm->{'vlans'}}) {
        my $vlan = $self->nm->{'vlans'}->{$vlan_id};
        if ($vlan->{'vlan'} eq $params{'number'}) {
            return $vlan;
        }
    }

    $self->logger->error("No VLAN with number: " . $params{'number'});
    return undef;
}

=head2 set_vlan_endpoints

=cut
sub set_vlan_endpoints {
    my $self = shift;
    my %params = @_;

    if (!defined $params{'vlan_id'}) {
        $self->logger->error("No VLAN ID specified");
        return;
    }

    if (defined $self->nm->{'vlans'}->{$params{'vlan_id'}}) {
        $self->nm->{'vlans'}->{$params{'vlan_id'}}->{'endpoints'} = $params{'endpoints'};
        $self->_write_network_model();
        return $self->nm->{'vlans'}->{$params{'vlan_id'}};
    }

    $self->logger->error("No VLAN with ID: " . $params{'vlan_id'});
    return undef;
}

1;
