#!/usr/bin/perl

package VCE::Device::JUNOS::MX::17;

use strict;
use warnings;
use Moo;
extends 'VCE::Device';

use Data::Dumper;
use GRNOC::Comm;
use GRNOC::NetConf::Device;
use Scalar::Util qw(looks_like_number);

has comm => (is => 'rwp');

has conn => (is => 'rwp');

has in_configure => (is => 'rwp', default => 0);
has context => (is => 'rwp', default => '');
has error => (is => 'rwp', default => '');
=head1 Package 17
    use VCE::Device::JUNOS::MX::17;
=cut

=head2 BUILD
    my $device = VCE::Device::JUNOS::MX::17->new(
        username => $username,
        password => $password,
        hostname => $hostname,
        port     => $port
    );
=over 4
=item comm
=item conn
=item error
=item in_configure
=item context
=back
=cut

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE::Device::JUNOS::MX::17");
    $self->_set_logger($logger);

    return $self;
}

=head2 connect
    my $err = connect();
connect creates a CLI connection and NetConf session to this
device. Returns an error string if connecting fails.
=cut
sub connect{
    my $self = shift;
    my %params = @_;

    my $err;
    my $comm = GRNOC::Comm->new(
        host => $self->hostname,
        user => $self->username,
        password => $self->password,
        device => 'juniper',
        key_delay => .001,
        debug => 0
	);
    $comm->login();

    if ($comm->connected()) {
        $self->_set_comm($comm);
        $self->_set_connected(1);
    } else {
        $err = "Error: " . $comm->get_error();
        $self->logger->error($err);
        $self->_set_connected(0);
    }

    my $conn = GRNOC::NetConf::Device->new(
        username => $self->username,
        password => $self->password,
        host     => $self->hostname,
        port     => 830,
        type     => 'JUNOS',
        model    => 'MX',
        version  => '17'
	);
    $self->_set_conn($conn);

    return $err;
}


=head2 disconnect
    disconnect();
disconnect closes any connections to the device.
=cut
sub disconnect{
    my $self = shift;
    my %params = @_;

    eval {
        $self->_set_connected(0);

        $self->comm->close();
        $self->_set_comm(undef);

        $self->conn->device->ssh->disconnect();
        $self->_set_conn(undef);
    };
    if ($@) {
        $self->logger->fatal("$@");
    }
    return 1;
}

=head2 reconnect
    reconnect();
reconnect closes all connections to this device and then reopens them.
=cut
sub reconnect {
    my $self = shift;

    $self->logger->info("Attempting to reconnect to " . $self->hostname);
    $self->disconnect();

    my $err = $self->connect();
    if (defined $err) {
        $self->logger->error($err);
    }
}


=head2 get_interfaces_state
    my ($interfaces, $err) = get_interfaces_state();
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

sub get_interfaces {
    my $self = shift;

    my $ints = $self->conn->get_interfaces();
    warn "INTERFACES: " . Dumper($ints);
    my %ints;

    foreach my $int (@$ints){
	if(!defined($int->{'description'})){
	    $int->{'description'} = $int->{'name'};
	}

	if($int->{'status'} eq 'up'){
	    $int->{'status'} = 1;
	}else{
	    $int->{'status'} = 0;
	}

	if($int->{'admin_status'} eq 'up'){
	    $int->{'admin_status'} = 1;
	}else{
	    $int->{'admin_status'} = 0;
	}
	
	if(ref $int->{'mac_addr'} eq ref {}){
		my $sub = $int->{'mac_addr'}->{'content'};
		$sub =~ s/^\s*(.*?)\s*$/$1/;
		$int->{'mac_addr'} = $sub;
	}
	#print $int->{'hardware_type'} . "\n";
	if(index($int->{'hardware_type'}, 'mbps') != -1){
		my @sub = split('mbps', $int->{'hardware_type'});
		$sub[0] = $sub[0]/1000;
		$sub[0] = $sub[0] . "GigabitEthernet";
		$int->{'hardware_type'} = $sub[0];
	}
			
	$ints{$int->{'name'}} = $int;
	
    }

    warn "Hash INTS: " .Dumper(%ints);

    return {interfaces => \%ints};
}

sub get_vlans{
    my $self = shift;

    my $xml = "";
    my $writer = XML::Writer->new( OUTPUT => \$xml);
    #<rpc>
    #<get-bridge-instance-information>
    #<detail/>
    #</get-bridge-instance-information>
    #</rpc>

    $writer->startTag("rpc");
    $writer->startTag("get-bridge-instance-information");
    $writer->startTag("detail");
    $writer->endTag("detail");
    $writer->endTag("get-bridge-instance-information");
    $writer->endTag("rpc");
    $writer->end();
    my $res = $self->conn->send($xml);
    my $resp = $self->conn->recv();
    #print $resp->{'l2ald-bridge-instance-information'} . "\n";
    #print $resp->{'l2ald-bridge-instance-information'}->{'l2ald-bridge-instance-group'};
    my $bridges = $resp->{'l2ald-bridge-instance-information'}->{'l2ald-bridge-instance-group'};
    my $result = [];
    foreach my $bridge (@$bridges){
	my $ports = [];
	if(looks_like_number($bridge->{'l2rtb-bridge-vlan'})){
	if (ref($bridge->{'l2rtb-interface-name'}) ne 'ARRAY') {
            $bridge->{'l2rtb-interface-name'} = [ $bridge->{'l2rtb-interface-name'} ];
        }

        foreach my $port (@{$bridge->{'l2rtb-interface-name'}}) {
		push(@{$ports}, { port => $port, mode => "TAGGED" });
        }	
	push (@$result, {vlan => $bridge->{'l2rtb-bridge-vlan'}, name => $bridge->{'l2rtb-bridging-domain'}, ports => $ports});
	}
    } 
    return $result;    

}

#Not being used yet
sub add_vlans{
    my $self = shift;

    my $xml = "";
    my $writer = XML::Writer->new( OUTPUT => \$xml);
    #<rpc-reply xmlns:junos="http://xml.juniper.net/junos/15.1F6/junos">
    #<configuration junos:commit-seconds="1564587526" junos:commit-localtime="2019-07-31 15:38:46 UTC" junos:commit-user="bmerugur">
    #        <interfaces>
    #            <interface>
    #                <name>ge-0/0/4</name>
    #                <per-unit-scheduler/>
    #                <flexible-vlan-tagging/>
    #                <mtu>9192</mtu>
    #                <encapsulation>flexible-ethernet-services</encapsulation>
    #                <unit>
    #                    <name>777</name>
    #                    <encapsulation>vlan-bridge</encapsulation>
    #                    <vlan-id>777</vlan-id>
    #                </unit>
    #            </interface>
    #        </interfaces>
    #	     <bridge-domains>
    #            <domain>
    #                <name>VCE-test</name>
    #                <domain-type>bridge</domain-type>
    #                <vlan-id>777</vlan-id>
    #                <interface>
    #                    <name>ge-0/0/4.777</name>
    #                </interface>
    #                <interface>
    #                    <name>ge-0/0/1.777</name>
    #                </interface>
    #            </domain>
    #        </bridge-domains>
    #</configuration>
    #<cli>
    #    <banner></banner>
    #</cli>
    #</rpc-reply>
    my $interf = "ge-0/0/4";
    my $vlanid = 810;
    my $bridgename = "VCE--testing...";

    $writer->startTag("rpc");
    $writer->startTag("edit-config");
    $writer->startTag("target");
    $writer->startTag("candidate");
    $writer->endTag("candidate");
    $writer->endTag("target");
    $writer->startTag("config");
    $writer->startTag("configuration");
    $writer->startTag("interfaces");
    $writer->startTag("interface");
    $writer->startTag("name");
    $writer->characters($interf);
    $writer->endTag("name");
    $writer->startTag("per-unit-scheduler");
    $writer->endTag("per-unit-scheduler");
    $writer->startTag("flexible-vlan-tagging");
    $writer->endTag("flexible-vlan-tagging");
    $writer->startTag("mtu");
    $writer->characters("9192");
    $writer->endTag("mtu");
    $writer->startTag("encapsulation");
    $writer->characters("flexible-ethernet-services");
    $writer->endTag("encapsulation");
    $writer->startTag("unit");
    $writer->startTag("name");
    $writer->characters($vlanid);
    $writer->endTag("name");
    $writer->startTag("encapsulation");
    $writer->characters("vlan-bridge");
    $writer->endTag("encapsulation");
    $writer->startTag("vlan-id");
    $writer->characters($vlanid);
    $writer->endTag("vlan-id");
    $writer->endTag("unit");
    $writer->endTag("interface");
    $writer->endTag("interfaces");
    $writer->startTag("bridge-domains");
    $writer->startTag("domain");
    $writer->startTag("name");
    $writer->characters($bridgename);
    $writer->endTag("name");
    $writer->startTag("domain-type");
    $writer->characters("bridge");
    $writer->endTag("domain-type");
    $writer->startTag("vlan-id");
    $writer->characters($vlanid);
    $writer->endTag("vlan-id");
    $writer->startTag("interface");
    $writer->startTag("name");
    $writer->characters($interf . "." . $vlanid);
    $writer->endTag("name");
    $writer->endTag("interface");
    $writer->endTag("domain");
    $writer->endTag("bridge-domains");
    $writer->endTag("configuration");
    $writer->endTag("config");
    $writer->endTag("edit-config");
    $writer->endTag("rpc");
    $writer->end();
   
    $writer->startTag("rpc");
    $writer->startTag("commit");
    $writer->endTag("commit");
    $writer->endTag("rpc"); 
    $writer->end();

    my $res = $self->conn->send($xml);
    my $resp = $self->conn->recv();
    return $resp;
   
}

=head2 interface_tagged
Using netconf connection $conn add interfaces $ifaces to VLAN
$vlan_id. Returns a response and error; The error is undef if nothing
failed.
=cut

sub interface_tagged{
    my $self    = shift;
    my $ifaces  = shift;
    my $vlan_id = shift;
     
    #changes--
    #my $desc = shift;
    #$self->logger->info("----------------In interface tagged-----------------------vlanid is " . $vlan_id . " and iface is " . $ifaces);# . " and desc is " . $desc);    
    my $xml = "";
    my $writer = XML::Writer->new( OUTPUT => \$xml);

    $writer->startTag("configuration");
    $writer->startTag("interfaces");
    foreach my $iface (@$ifaces){
        $writer->startTag("interface");
        $writer->startTag("name");
        $writer->characters($iface);
        $writer->endTag();
        $writer->startTag("unit");
        $writer->startTag("name");
        $writer->characters($vlan_id);
        $writer->endTag();
        $writer->startTag("vlan-id");
        $writer->characters($vlan_id);
        $writer->endTag();
        $writer->endTag();
        $writer->endTag();
    }
    $writer->endTag();

    $writer->startTag("bridge-domains");
    $writer->startTag("domain");
    $writer->startTag("name");
    $writer->characters("vlan" . $vlan_id);
    $writer->endTag();
    $writer->startTag("vlan-id");
    $writer->characters($vlan_id);
    $writer->endTag();

    foreach my $iface (@$ifaces){
        $writer->startTag("interface");
        $writer->startTag("name");
        $writer->characters($iface . "." . $vlan_id);
        $writer->endTag();
        $writer->endTag();
    }


    $writer->endTag();
    $writer->endTag();
    $writer->endTag();
    $writer->end();

    my $res = $self->conn->edit_configuration(config => $xml);
    warn Dumper($res);
   
}

sub no_interface_tagged{
    my $self    = shift;
    my $ifaces  = shift;
    my $vlan_id = shift;

    my $xml = "";
    my $writer = XML::Writer->new( OUTPUT => \$xml);

    $writer->startTag("configuration");
    $writer->startTag("interfaces");
    foreach my $iface (@$ifaces){
        $writer->startTag("interface");
        $writer->startTag("name");
	$writer->characters($iface);
        $writer->endTag();
        $writer->startTag("unit", operation => 'delete');

        $writer->startTag("name");
	$writer->characters($vlan_id);
        $writer->endTag();
        $writer->endTag();
    }

    $writer->startTag("bridge-domains");
    $writer->startTag("domain");
    $writer->startTag("name", operation => 'delete');
    $writer->characters("vlan" . $vlan_id);
    $writer->endTag();
    $writer->endTag();
    $writer->endTag();
    $writer->endTag();
    $writer->end();

    my $res = $self->conn->edit_configuration(config => $xml);
    warn Dumper($res);
}


sub no_vlan{
    my $self = shift;
    my $vlan_id = shift;

    my $xml = "";
    my $writer = XML::Writer->new( OUTPUT => \$xml);
    $writer->startTag("configuration");
    $writer->startTag("bridge-domains");
    $writer->startTag("domain");
    $writer->startTag("name", operation => 'delete');
    $writer->characters("vlan" . $vlan_id);
    $writer->endTag();
    $writer->endTag();
    $writer->endTag();
    $writer->endTag();
    $writer->end();

    $self->conn->edit_configuration(config => $xml);

}

sub vlan_description{
    my $self = shift;
    my $desc = shift;
    my $vlan_id = shift;

    my $xml = "";
    my $writer = XML::Writer->new( OUTPUT => \$xml);
    $writer->startTag("configuration");
    $writer->startTag("bridge-domains");
    $writer->startTag("domain");
    $writer->startTag("name");
    $writer->characters("vlan" . $vlan_id);
    $writer->endTag();
    $writer->startTag("description");
    $writer->characters($desc);
    $writer->endTag();
    $writer->endTag();
    $writer->endTag();
    $writer->endTag();

    $writer->end();

    $self->conn->edit_configuration(config => $xml);
}

sub no_vlan_spanning_tree{
    
    

}

sub vlan_spanning_tree{
    
    

}



=head2 configure
    my $ok = configure();
    configure enters into this device's configuration mode.
=cut
sub configure{
    my $self = shift;

    if ($self->in_configure) {
        $self->logger->debug("Already in configure mode");
        return 1;
    }

    my ($result, $err) = $self->issue_command("configure private", "#");
    if (defined $err) {
        return 0;
    }

    $self->_set_in_configure(1);
    return 1;
}


=head2 exit_configure
    my $ok = exit_configure();
    exit_configure exits this device's configuration mode.
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
    my ($result, $err) = $self->issue_command("commit", "#");
    ($result, $err) = $self->issue_command("exit", $self->comm->{'default_prompt'});
    if (defined $err) {
        return 0;
    }

    $self->_set_in_configure(0);
    return 1;
}

=head2 set_context
    my $ok = set_context('vlan 218');
set_context changes the context in which a command is run. For
example, to enable spanning tree on a per-VLAN basis you must first
run C<conf t> and C<vlan 218> before C<spanning-tree> is executed.
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
    my $ok = exit_context();
exit_context exits this device's current CLI context.
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
    my ($res, $err) = issue_command($command, $prompt);
issue_command returns the output generated by executing C<$command> on
this device. The output includes all data up to C<$prompt>.
=cut
sub issue_command{
    my $self    = shift;
    my $command = shift;
    my $prompt  = shift;

    my $statements_run = 0;
    my @statements = split(/;\s*/, $command);
    my $result = undef;

    foreach my $statement (@statements) {
        $self->logger->info("Running command: $statement");

        $result = $self->comm->issue_command($statement, $prompt);
        if (!defined $result) {
            my $err = $self->comm->get_error();
            $self->comm->clear_error();

            # TODO Remove context tracking
            $self->_set_context('');
            $self->_set_in_configure(0);

            return (undef, $err);
        }

        $statements_run += 1;
    }

    # Consider running C<conf t>, C<vlan 218>, C<spanning-tree>. To
    # exit to the main menu, exit should be run twice: One less than
    # the number of statements executed.
    for (my $i = 0; $i < $statements_run - 1; $i++) {
        my $ok = $self->comm->issue_command('exit', $prompt);
        if (!defined $ok) {
            # Failing to exit to the main menu isn't ideal, but also
            # not a deal breaker because we got the result of the
            # actual command.

            my $err = $self->comm->get_error();
            $self->comm->clear_error();
            last;
        }
    }

    # TODO Remove context tracking
    $self->_set_context('');
    $self->_set_in_configure(0);

    # Strip any leading whitespace including newlines.
    $result =~ s/\A\s+//gm;
    # Responses that end with n have the last character removed. I
    # don't know why, but this fixes the result for a known case. This
    # can be revisted if more issues arise.
    $result =~ s/vla\z/vlan/gm;

    return ($result, undef);
}

1;
