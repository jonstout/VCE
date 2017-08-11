#!/usr/bin/perl

package VCE::Device::Brocade::MLXe::5_8_0;

use strict;
use warnings;
use Moo;
extends 'VCE::Device';

use Data::Dumper;
use GRNOC::Comm;
use GRNOC::NetConf::Device;

has comm => (is => 'rwp');

has conn => (is => 'rwp');

has in_configure => (is => 'rwp', default => 0);
has context => (is => 'rwp', default => '');

=head2 BUILD

=over 4

=item comm

=item conn

=item context

=item in_configure

=back    

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

    my $comm = GRNOC::Comm->new( host => $self->hostname,
                                 user => $self->username,
                                 password => $self->password,
                                 device => 'brocade',
                                 key_delay => .001,
                                 debug => 0 );
    $comm->login();

    if ($comm->connected()) {
        $self->_set_comm($comm);
        $self->_set_connected(1);
    } else {
        $self->logger->error( "Error: " . $comm->get_error());
        $self->_set_connected(0);
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

=head2 get_interfaces_state

get_interfaces_state uses netconf to retrieve basic information about
each interface; It returns an array of interfaces and an error if a
failure occurred. An example interface is included below.

  {
    id         => 'ethernet 15/2'
    duplex     => 'full',
    hw_addr    => 'cc4e.240c.0ea1',
    link_state => 'up'
    name       => 'mat lok',
    port_state => 'forward',
    priority   => 'level0',
    speed      => '10G',
    tag        => 'no'
  }

=cut
sub get_interfaces_state {
    my $self = shift;

    my $err = undef;
    my $req = "
<nc:rpc message-id=\"1\" xmlns:nc=\"urn:ietf:params:xml:ns:netconf:base:1.0\"  xmlns:brcd=\"http://brocade.com/ns/netconf/config/netiron-config/\">
  <nc:get>
    <nc:filter nc:type=\"subtree\">
      <brcd:netiron-statedata>
        <brcd:interface-statedata/>
      </brcd:netiron-statedata>
    </nc:filter>
  </nc:get>
</nc:rpc>";

    my $ok = $self->conn->send($req);
    if (!defined $ok) {
        $err = "Could not get interfaces' state.";
        $self->conn->disconnect();
        return undef, $err;
    }

    my $res = $self->conn->recv();
    if (!defined $res->{'nc:ok'} && keys %{$res->{'nc:rpc-error'}}) {
        $err = $res->{'nc:rpc-error'}->{'nc:error-message'};
        return undef, $err;
    }

    my $data = $res->{'nc:data'}->{'netiron-statedata'}->{'brcd:interface-statedata'}->{'brcd:interface'};
    my $interfaces = [];

    foreach my $raw (@{$data}) {
        my $duplex = 'unkown';
        $duplex = 'full' if (exists $raw->{'brcd:duplex'}->{'brcd:full'});
        $duplex = 'half' if (exists $raw->{'brcd:duplex'}->{'brcd:half'});
        $duplex = 'none' if (exists $raw->{'brcd:duplex'}->{'brcd:none'});
        $duplex = 'na' if (exists $raw->{'brcd:duplex'}->{'brcd:na'});

        my $link_state = 'unkown';
        $link_state = 'up' if (exists $raw->{'brcd:link-state'}->{'brcd:up'});
        $link_state = 'down' if (exists $raw->{'brcd:link-state'}->{'brcd:down'});
        $link_state = 'disabled' if (exists $raw->{'brcd:link-state'}->{'brcd:disabled'});

        my $port_state = 'unkown';
        $port_state = 'forward' if (exists $raw->{'brcd:l2-state'}->{'brcd:forward'});

        my $tag = 'unknown';
        $tag = 'no' if (exists $raw->{'brcd:tag-mode'}->{'brcd:no'});
        $tag = 'yes' if (exists $raw->{'brcd:tag-mode'}->{'brcd:yes'});

        my $priority = 'unknown';
        $priority = 'level0' if (exists $raw->{'brcd:priority-level'}->{'brcd:level0'});

        my $interface = {
            id         => $raw->{'brcd:interface-id'},
            duplex     => $duplex,
            hw_addr    => $raw->{'brcd:mac-address'},
            link_state => $link_state,
            name       => $raw->{'brcd:name'} || '',
            port_state => $port_state,
            priority   => $priority,
            speed      => $raw->{'brcd:speed'},
            tag        => $tag
        };

        push(@{$interfaces}, $interface);
    }

    return $interfaces, $err;
}

=head2 get_interfaces

=cut
sub get_interfaces {
    my $self = shift;
    my %params = @_;

    if (!$self->connected) {
        $self->logger->error("not currently connected to the device");
        return;
    }

    my ($ints, $err) = $self->get_interfaces_state();
    if (defined $err) {
        $self->logger->error($err);
    }

    my %interfaces;

    my $raw = "";
    foreach my $int (@$ints){
        my $int_details = $self->_get_interface(name => $int->{'id'});
        next if(!defined($int_details));
        next if(!defined($int_details->{'parsed'}->{'name'}));

        $int_details->{'parsed'}->{'description'} = $int->{'name'};

        $raw .= $int_details->{'raw'};
        $interfaces{$int->{'id'}} = $int_details->{'parsed'};
    }

    return {interfaces => \%interfaces, raw => $raw};
}

=head2 vlan_description

vlan_description sets vlan $vlan_id's description to $desc. Returns a
response and error; The error is undef if nothing failed.

=cut
sub vlan_description {
    my $self    = shift;
    my $desc    = shift;
    my $vlan_id = shift;

    my $err = undef;
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
            <brcd:vlan-name>$desc</brcd:vlan-name>
          </brcd:vlan>
        </brcd:vlan-config>
      </brcd:netiron-config>
    </nc:config>
  </nc:edit-config>
</nc:rpc>";

    my $ok = $self->conn->send($req);
    if (!defined $ok) {
        $err = "Could not set vlan $vlan_id description.";
        $self->conn->disconnect();
        return undef, $err;
    }

    my $res = $self->conn->recv();
    if (!defined $res->{'nc:ok'}) {
        $err = $res->{'nc:rpc-error'}->{'nc:error-message'};
    }

    return $res, $err;
}

=head2 no_vlan

no_vlan removes $vlan_id from this switch. Returns a response and
error; The error is undef if nothing failed.

=cut
sub no_vlan {
    my $self    = shift;
    my $vlan_id = shift;

    my $err = undef;
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
          <brcd:vlan nc:operation=\"delete\">
            <brcd:vlan-id>$vlan_id</brcd:vlan-id>
          </brcd:vlan>
        </brcd:vlan-config>
      </brcd:netiron-config>
    </nc:config>
  </nc:edit-config>
</nc:rpc>";

    my $ok = $self->conn->send($req);
    if (!defined $ok) {
        $err = "Could not delete vlan $vlan_id.";
        $self->conn->disconnect();
        return undef, $err;
    }

    my $res = $self->conn->recv();
    if (!defined $res->{'nc:ok'}) {
        $err = $res->{'nc:rpc-error'}->{'nc:error-message'};
    }

    return $res, $err;
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

    my $err = undef;
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

    my $ok = $self->conn->send($req);
    if (!defined $ok) {
        $err = "Could not add vlan $vlan_id to $iface.";
        $self->conn->disconnect();
        return undef, $err;
    }

    my $res = $self->conn->recv();
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

    my $err = undef;
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

    my $ok = $self->conn->send($req);
    if (!defined $ok) {
        $err = "Could not remove vlan $vlan_id from $iface.";
        $self->conn->disconnect();
        return undef, $err;
    }

    my $res = $self->conn->recv();
    if (!defined $res->{'nc:ok'}) {
        $err = $res->{'nc:rpc-error'}->{'nc:error-message'};
    }

    return $res, $err;
}


sub _get_interface{
    my $self = shift;
    my %params = @_;

    my $int_details;
    my $err;
    ($int_details, $err) = $self->issue_command("show interface " . $params{'name'});
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
            if($line =~ /line protocol/){
                $line =~ /(\S+)\s/;
                $int->{'name'} = $1;
                next if(!defined($int->{'name'}));
                $int->{'name'} =~ s/100GigabitEthernet/ethernet /;
                $int->{'name'} =~ s/40GigabitEthernet/ethernet /;
                $int->{'name'} =~ s/10GigabitEthernet/ethernet /;
                $int->{'name'} =~ s/GigabitEthernet/ethernet /;
                $int->{'name'} =~ s/Ethernetmgmt/management /;

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
            }else{
                next;
            }
        }
    }

    return {parsed => $int, raw => $int_details};
}

=head2 configure

=cut

sub configure{
    my $self = shift;

    if ($self->in_configure) {
        $self->logger->debug("Already in configure mode");
        return 1;
    }

    my ($result, $err) = $self->issue_command("configure terminal", "#");
    if (defined $err) {
        return 0;
    }

    $self->_set_in_configure(1);
    return 1;
}


=head2 exit_configure

=cut

sub exit_configure{
    my $self = shift;

    if(!$self->in_configure){
        $self->logger->debug("Already NOT in configure mode");
        return 1;
    }

    # When leaving configuration mode verify that the default prompt
    # is set in GRNOC:Comm.
    $self->logger->debug("Leaving configure mode and Setting default prompt: " . $self->comm->{'default_prompt'});
    my ($result, $err) = $self->issue_command("exit", $self->comm->{'default_prompt'});
    if (defined $err) {
        return 0;
    }

    $self->_set_in_configure(0);
    return 1;
}

=head2 set_context

=cut

sub set_context{
    my $self = shift;
    my $context = shift;

    if ($self->context ne '') {
        if ($self->context eq $context) {
            $self->logger->info("Already in context $context");
            return 1;
        } else {
            $self->logger->error("Already in context " . $self->context);
            return 0;
        }
    }

    my ($result, $err) = $self->issue_command($context, "#");
    if (defined $err) {
        return 0;
    }

    $self->_set_context($context);
    return 1;
}

=head2 exit_context

=cut
sub exit_context{
    my $self = shift;

    if ($self->context eq '') {
        $self->logger->debug("Already NOT in a context");
        return 1;
    }

    # Prompt of '#' is required to prevent a timeout from occurring in
    # the underlying GRNOC::Comm lib.
    my ($result, $err) = $self->issue_command("exit", "#");
    if (defined $err) {
        return 0;
    }

    $self->_set_context('');
    return 1;
}

=head2 issue_command

Returns results and error. Error will be undef if everything went ok.

=cut
sub issue_command{
    my $self    = shift;
    my $command = shift;
    my $prompt  = shift;

    my $err = undef;

    $self->logger->debug("Running command: $command");
    my $result = $self->comm->issue_command($command, $prompt);
    if (!defined $result) {
        $err = $self->comm->get_error();
        $self->logger->error($err);

        # Clear causes a reconnect to ensure valid switch context so
        # we clear our state after calling this.
        $self->comm->clear_error();
        $self->_set_context('');
        $self->_set_in_configure(0);
    }

    return ($result, $err);
}

1;
