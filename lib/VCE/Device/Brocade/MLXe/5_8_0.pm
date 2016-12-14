#!/usr/bin/perl

package VCE::Device::Brocade::MLXe::5_8_0;

use strict;
use warnings;

use Moo;
extends 'VCE::Device';

use GRNOC::Comm;
use GRNOC::NetConf::Device;

has comm => (is => 'rwp');
has conn => (is => 'rwp');

=head2 BUILD

=cut

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE::Device::Brocade::MLXe::5_8_0");
    $self->_set_logger($logger);

    return $self;
}

=head2 connect

=cut

sub connect{
    my $self = shift;
    my %params = @_;

    $self->logger->error( "" );
    
    my $comm = GRNOC::Comm->new( host => $self->hostname,
				 user => $self->username,
				 password => $self->password,
				 device => 'brocade',
				 key_delay => .001,
				 debug => 0 );

    $comm->login();
    
    if($comm->connected()){
	$self->_set_comm($comm);
	$self->_set_connected(1);
    }else{
	$self->logger->error( "Error: " . $comm->get_error());
	return;
    }

    my $conn = GRNOC::NetConf::Device->new(username => $self->username,
                                           password => $self->password,
                                           host     => $self->hostname,
                                           port     => 830,
                                           type     => 'Brocade',
                                           model    => 'MLXe',
                                           version  => '5.8.0');
    $self->_set_conn($conn);

    return;
}



=head2 get_interfaces

=cut

sub get_interfaces{
    my $self = shift;
    my %params = @_;

    if($self->connected){
	my %interfaces;
	my $interfaces_brief = $self->comm->issue_command('show interfaces brief');
	my $ints = $self->_process_interfaces($interfaces_brief);
        my $raw = "";
	foreach my $int (@$ints){
	    my $int_details = $self->_get_interface( name => $int->{'port_name'});
	    next if(!defined($int_details));
	    $interfaces{$int_details->{'parsed'}->{'name'}} = $int_details->{'parsed'};
            $raw .= $int_details->{'raw'};
	}
	return {interfaces => \%interfaces, raw => $raw};
    }else{
	$self->logger->error("not currently connected to the device");
	return;
    }

}

=head2 interface_tagged

Using netconf connection $conn add interface $iface to VLAN
$vlan_id. Returns a response and error; The error is undef if nothing
failed.

=cut
sub interface_tagged {
    my $self    = shift;
    my $iface   = shift;
    my $vlan_id = shift;

    my $req = "
<nc:rpc message-id=\"1\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"  xmlns:brcd=\"http://brocade.com/ns/netconf/config/netiron-config/\">
  <nc:edit-config>
    <nc:target>
      <nc:running/>
    </nc:target>
    <nc:default-operation>merge</nc:default-operation>
    <nc:config>
      <brcd:netiron-config>
        <brcd:vlan-config>
          <brcd:vlan>
            <brcd:vlan-id>$vlan_id</brcd:vlan-id>
            <brcd:tagged>$iface</brcd:tagged>
          </brcd:vlan>
        </brcd:vlan-config>
      </brcd:netiron-config>
    </nc:config>
  </nc:edit-config>
</nc:rpc>";

    $self->conn->send($req);

    my $res = $self->conn->recv();
    my $err = undef;

    if (!defined $res->{'nc:ok'}) {
        $err = $res->{'nc:rpc-error'}->{'nc:error-message'};
    }
    return $res, $err;
}

=head2 no_interface_tagged

Using netconf connection $conn remove interface $iface from VLAN
$vlan_id. Returns a response and error; The error is undef if nothing
failed.

=cut
sub no_interface_tagged {
    my $self    = shift;
    my $iface   = shift;
    my $vlan_id = shift;

    my $req = "
<nc:rpc message-id=\"1\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"  xmlns:brcd=\"http://brocade.com/ns/netconf/config/netiron-config/\">
  <nc:edit-config>
    <nc:target>
      <nc:running/>
    </nc:target>
    <nc:default-operation>merge</nc:default-operation>
    <nc:config>
      <brcd:netiron-config>
        <brcd:vlan-config>
          <brcd:vlan>
            <brcd:vlan-id>$vlan_id</brcd:vlan-id>
            <brcd:tagged nc:operation=\"delete\">$iface</brcd:tagged>
          </brcd:vlan>
        </brcd:vlan-config>
      </brcd:netiron-config>
    </nc:config>
  </nc:edit-config>
</nc:rpc>";

    $self->conn->send($req);

    my $res = $self->conn->recv();
    my $err = undef;

    if (!defined $res->{'nc:ok'}) {
        $err = $res->{'nc:rpc-error'}->{'nc:error-message'};
    }
    return $res, $err;
}


sub _get_interface{
    my $self = shift;
    my %params = @_;

    my $int_details;
    if($params{'name'} =~ /\d+\/\d+/){
	$int_details = $self->comm->issue_command("show interface ethernet " . $params{'name'});
    }elsif( $params{'name'} =~ /mgmt(\d+)/){
	$int_details = $self->comm->issue_command("show interface management " . $1);
    }else{
	$int_details = $self->comm->issue_command("show interface " . $params{'name'});
    }

    return if(!defined($int_details));

    

    my $int = {};
    foreach my $line (split(/\n/,$int_details)){
	if($line =~ /^\s/){
	    
	    if($line =~ /Hardware is (\S+), address is (\S+)/){
		$int->{'hardware_type'} = $1;
		$int->{'mac_addr'} = $2;
	    }

	    if($line =~ /Configured speed (\S+), actual (\S+), configured duplex (\S+), actual (\S+)/){
		$int->{'speed'} = $2;
	    }

	    if($line =~ /MTU (\d+)/){
		$int->{'mtu'} = $1;
	    }
	    
	    if($line =~ /(\d+) packets input, (\d+) bytes, (\d)/){
		$int->{'input'} = {};
		$int->{'input'}->{'packets'} = $1;
		$int->{'input'}->{'bytes'} = $2;
	    }

	    if($line =~ /(\d+) input errors, (\d+) CRC, (\d+) frame, (\d+) ignored/){
		$int->{'input'}->{'errors'} = $1;
		$int->{'input'}->{'CRC_errors'} = $2;
		$int->{'input'}->{'error_frames'} = $3;
		$int->{'input'}->{'ignored'} = $4;
	    }

	    if($line =~ /(\d+) packets input, (\d+) bytes, (\d)/){
		$int->{'output'} = {};
		$int->{'output'}->{'packets'} = $1;
		$int->{'output'}->{'bytes'} = $2;
	    }

            if($line =~ /(\d+) output errors, (\d+) collisions/){
                $int->{'output'}->{'errors'} = $1;
                $int->{'output'}->{'collisions'} = $2;
            }

	}else{
	    $line =~ /(\S+)\s/;
	    $int->{'name'} = $1;
            next if(!defined($int->{'name'}));
            $int->{'name'} =~ s/100GigabitEthernet/ethernet /;
            $int->{'name'} =~ s/10GigabitEthernet/ethernet /;
            $int->{'name'} =~ s/GigabitEthernet/ethernet /;

            $line =~ /is (\S+), line protocol is (\S+)/;
            $int->{'admin_status'} = $1;
            $int->{'status'} = $2;

            if($int->{'admin_status'} eq 'disabled'){
                $int->{'admin_status'} = 0;
            }else{
                $int->{'admin_status'} = 1;
            }

            if(defined($int->{'status'})){
                
                if($int->{'status'} eq 'up'){
                    $int->{'status'} = 1;
                }elsif($int->{'status'} eq 'down'){
                    $int->{'status'} = 0;
                }else{
                    $int->{'status'} = 'unknown';
                }
            }
        }

    }

    return {parsed => $int, raw => $int_details};
    
}

sub _process_interfaces{
    my $self = shift;
    my $interfaces_brief = shift;

    my @interfaces;
    foreach my $line (split(/\n/,$interfaces_brief)){
	next if($line =~ /Port/);
	next if($line eq '');

	$line =~ /(\S+)\s+(\S+)\s+(\S+)(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/g;

	my $int = {};
	$int->{'port_name'} = $1;
	$int->{'state'} = $2;
	$int->{'port_state'} = $3;
	$int->{'duplex'} = $4;
	$int->{'speed'} = $5;
	$int->{'trunk'} = $6;
	$int->{'tag'} = $7;
	$int->{'priority'} = $8;
	$int->{'mac'} = $9;
	$int->{'name'} = $10;
	$int->{'type'} = $11;

	push(@interfaces,$int);
    }

    return \@interfaces;
}

1;
