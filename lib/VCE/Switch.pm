#!/usr/bin/perl

package VCE::Switch;

use strict;
use warnings;

use Data::Dumper;
use Moo;
use GRNOC::Log;
use GRNOC::RabbitMQ::Method;
use GRNOC::RabbitMQ::Dispatcher;
use GRNOC::WebService::Regex;

use VCE::Device;
use VCE::Device::Brocade::MLXe::5_8_0;

has logger => (is => 'rwp');
has device => (is => 'rwp');
has type => (is => 'rwp');
has vendor => (is => 'rwp');
has version => (is => 'rwp');
has username => (is => 'rwp');
has password => (is => 'rwp');
has port => (is => 'rwp');
has hostname => (is => 'rwp');
has dispatcher => (is => 'rwp');
has rabbit_mq => (is => 'rwp');
has op_state => (is => 'rwp');
has name => (is => 'rwp');

=head2 BUILD

=over 4

=item vce

=item logger

=item device

=item type

=item vendor

=item version

=item username

=item password

=item port

=item hostname

=item dispatcher

=item rabbit_mq

=item op_state

=item op_state

=item name

=back

=cut

sub BUILD{
    my ($self) = @_;
    
    my $logger = GRNOC::Log->get_logger("VCE::Switch");
    $self->_set_logger($logger);

    $0 = "VCE(" . $self->username . ")";

    $self->logger->error("Creating Dispatcher");
    my $dispatcher = GRNOC::RabbitMQ::Dispatcher->new( host => $self->rabbit_mq->{'host'},
                                                       port => $self->rabbit_mq->{'port'},
                                                       user => $self->rabbit_mq->{'user'},
                                                       pass => $self->rabbit_mq->{'pass'},
                                                       exchange => 'VCE',
                                                       queue => 'VCE-Switch',
                                                       topic => 'VCE.Switch.RPC');


    $self->_register_rpc_methods( $dispatcher );

    $self->_set_dispatcher($dispatcher);

    $self->logger->error("Connecting to device");

    $self->_connect_to_device();

    if(!defined($self->device)){
	$self->logger->error("Error connecting to device");
    }

    $SIG{'TERM'} = sub {
        $self->logger->info( "Received SIG TERM." );
        $self->stop();
    };

    $self->logger->error("Creating timers");

    $self->{'operational_status_timer'} = AnyEvent->timer(after => 10, interval => 300, cb => sub { $self->_gather_operational_status() });

    $self->{'reconnect_timer'} = AnyEvent->timer(after => 10, interval => 10, cb => sub { $self->_reconnect_to_device() });

    return $self;
}

sub _reconnect_to_device{
    my $self = shift;

    if(defined($self->device) && $self->device->connected){
        $self->logger->debug("Already connected");
        return;
    }

    $self->logger->info("Attempt to connect");
    return $self->device->connect();
}

sub _connect_to_device{
    my $self = shift;

    $self->logger->debug("connecting to device");

    if($self->vendor eq 'Brocade'){
        if($self->type eq 'MLXe'){
            if($self->version eq '5.8.0'){
                my $dev = VCE::Device::Brocade::MLXe::5_8_0->new( username => $self->username,
                                                                  password => $self->password,
                                                                  hostname => $self->hostname,
                                                                  port => $self->port);

                $self->_set_device($dev);
                $dev->connect();
                if($dev->connected){
                    $self->logger->debug( "Successfully connected to device!" );
                    return 1;
                }else{
                    $self->logger->error( "Error connecting to device");
                    return;
                }
            }else{
                $self->logger->error( "No supported Brocade MLXe module for version " . $self->version );
                return;
            }
        }else{
            $self->logger->error( "No supported Brocade module for devices of type " . $self->type );
            return;
        }
    }else{
        $self->logger->error( "No supported vendor of type " . $self->vendor );
        return;
    }

}

sub _register_rpc_methods{
    my $self = shift;
    my $d = shift;

    my $method = GRNOC::RabbitMQ::Method->new( name => "get_interfaces",
					       callback => sub { return $self->get_interfaces( @_ )  },
					       description => "Get the device interfaces" );
    $method->add_input_parameter( name => "interface_name",
				  description => "Name of the interface to gather data about",
				  required => 0,
				  multiple => 1,
				  pattern => $GRNOC::WebService::Regex::NAME_ID );
    $d->register_method($method);

    $method = GRNOC::RabbitMQ::Method->new( name => "get_interface_status",
                                            callback => sub { return $self->get_interface_status( @_ )  },
                                            description => "Get the device interfaces" );

    $method->add_input_parameter( name => "interface",
                                  description => "Name of the interface to gather data about",
                                  required => 1,
                                  multiple => 0,
                                  pattern => $GRNOC::WebService::Regex::NAME_ID );
    $d->register_method($method);

    $method = GRNOC::RabbitMQ::Method->new(
        name => "get_vlans",
        callback => sub { return $self->get_vlans(@_) },
        description => "Get the device vlans"
    );
    $d->register_method($method);

    $method = GRNOC::RabbitMQ::Method->new( name => "get_interfaces_op",
                                            callback => sub { return $self->get_interfaces_op( @_ )  },
                                            description => "Get the device interfaces" );
    $d->register_method($method);
    
    $method = GRNOC::RabbitMQ::Method->new( name => "get_device_status",
                                            callback => sub { return $self->get_device_status( @_ )  },
                                            description => "Get the device status" );

    $d->register_method($method);

    $method = GRNOC::RabbitMQ::Method->new( name => "execute_command",
                                            callback => sub { return $self->execute_command( @_ )  },
                                            description => "executes a command" );
    
    $method->add_input_parameter( name        => "command",
                                  description => "Actual command to run",
                                  required    => 1,
                                  pattern     => $GRNOC::WebService::Regex::TEXT );
    
    $method->add_input_parameter( name        => "context",
                                  description => "Any context for the command",
                                  required    => 0,
                                  pattern     => $GRNOC::WebService::Regex::TEXT );

    $method->add_input_parameter( name        => "config",
                                  description => "Does this command need to be done in commadn mode",
                                  required    => 1,
                                  default     => 0,
                                  pattern     => $GRNOC::WebService::Regex::BOOLEAN );

    $d->register_method($method);

    $method = GRNOC::RabbitMQ::Method->new( name => "vlan_description",
                                            callback => sub { return $self->vlan_description( @_ )  },
                                            description => "Sets a vlan's description" );
    $method->add_input_parameter( name        => "description",
				  description => "Description the vlan to add",
				  required    => 1,
				  pattern     => $GRNOC::WebService::Regex::TEXT );
    $method->add_input_parameter( name        => "vlan",
				  description => "VLAN number to use for tag",
				  required    => 1,
				  pattern     => $GRNOC::WebService::Regex::INTEGER );
    $d->register_method($method);

    $method = GRNOC::RabbitMQ::Method->new( name => "no_vlan",
                                            callback => sub { return $self->no_vlan(@_) },
                                            description => "Sets a vlan's description" );
    $method->add_input_parameter( name        => "vlan",
				  description => "VLAN number to use for tag",
				  required    => 1,
				  pattern     => $GRNOC::WebService::Regex::INTEGER );
    $d->register_method($method);

    $method = GRNOC::RabbitMQ::Method->new( name => "interface_tagged",
                                            callback => sub { return $self->interface_tagged( @_ )  },
                                            description => "Add vlan tagged interface" );
    $method->add_input_parameter( name        => "port",
				  description => "Name of the interface to add tag to",
				  required    => 1,
				  pattern     => $GRNOC::WebService::Regex::TEXT );
    $method->add_input_parameter( name        => "vlan",
				  description => "VLAN number to use for tag",
				  required    => 1,
				  pattern     => $GRNOC::WebService::Regex::INTEGER );
    $d->register_method($method);


    $method = GRNOC::RabbitMQ::Method->new( name => "no_interface_tagged",
                                            callback => sub { return $self->no_interface_tagged( @_ )  },
                                            description => "Remove vlan tagged interface" );
    $method->add_input_parameter( name        => "port",
				  description => "Name of the interface to remove tag from",
				  required    => 1,
				  pattern     => $GRNOC::WebService::Regex::TEXT );
    $method->add_input_parameter( name        => "vlan",
				  description => "VLAN number to use for tag",
				  required    => 1,
				  pattern     => $GRNOC::WebService::Regex::INTEGER );
    $d->register_method($method);
}


=head2 get_interfaces

=cut

sub get_interfaces{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    if($self->device->connected){
        return $self->device->get_interfaces();
    }else{
	$self->logger->error("Error device is not connected");
	return;
    }
}

=head2 get_interfaces_op

=cut

sub get_interfaces_op {
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    if (!defined $self->op_state || !defined $self->op_state->{'ports'}) {
        return {results => {}};
    }

    return {results => $self->op_state->{'ports'}};
}

=head2 get_vlans

get_vlans returns a hash of vlan objects describing this devices VLAN
configuration. This device's control and default VLANs are omitted
from the resulting hash. The mode of each port object will be 'TAGGED'
or 'UNTAGGED'.

Unlike get_interfaces, get_vlans has no associated _op method. All
requests for a device's VLAN configuration will be proxied through the
op_state variable.

=cut
sub get_vlans {
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    if (!defined $self->op_state || !defined $self->op_state->{'vlans'}) {
        return {};
    }

    return $self->op_state->{'vlans'};
}

=head2 vlan_description

=cut

sub vlan_description {
    my $self   = shift;
    my $method = shift;
    my $params = shift;

    my $desc = $params->{'description'}{'value'};
    my $vlan = $params->{'vlan'}{'value'};

    if (!$self->device->connected) {
        $self->logger->error("Error device is not connected.");
    }

    my ($res, $err) = $self->device->vlan_description($desc, $vlan);
    if (defined $err) {
        $self->logger->error($err);
        return { results => undef, error => $err };
    }

    return { results => 1 };
}


=head2 interface_tagged

=cut

sub interface_tagged {
    my $self   = shift;
    my $method = shift;
    my $params = shift;

    my $port = $params->{'port'}{'value'};
    my $vlan = $params->{'vlan'}{'value'};

    if (!$self->device->connected) {
        $self->logger->error("Error device is not connected.");
    }

    my ($res, $err) = $self->device->interface_tagged($port, $vlan);
    if (defined $err) {
        $self->logger->error($err);
        return { results => undef, error => $err };
    }

    return { results => 1 };
}

=head2 no_interface_tagged

=cut

sub no_interface_tagged {
    my $self   = shift;
    my $method = shift;
    my $params = shift;

    my $port = $params->{'port'}{'value'};
    my $vlan = $params->{'vlan'}{'value'};

    if (!$self->device->connected) {
        $self->logger->error("Error device is not connected.");
    }

    my ($res, $err) = $self->device->no_interface_tagged($port, $vlan);
    if (defined $err) {
        $self->logger->error($err);
        return { results => undef, error => $err };
    }

    return { results => 1 };
}

=head2 no_vlan

=cut

sub no_vlan {
    my $self   = shift;
    my $method = shift;
    my $params = shift;

    my $vlan = $params->{'vlan'}{'value'};

    if (!$self->device->connected) {
        $self->logger->error("Error device is not connected.");
    }

    my ($res, $err) = $self->device->no_vlan($vlan);
    if (defined $err) {
        $self->logger->error($err);
        return { results => undef, error => $err };
    }

    return { results => 1 };
}

=head2 get_device_status

=cut

sub get_device_status{
    my $self   = shift;
    my $method = shift;
    my $params = shift;

    return { status => $self->device->connected };
}

=head2 get_interface_status

=cut

sub get_interface_status{
    my $self   = shift;
    my $method = shift;
    my $params = shift;

    my $interface = $params->{'interface'}{'value'};

    if(!defined($interface)){
        $self->logger->error("No Interface defined");
        return {status => undef, error => {msg => "No state specified"}};
    }

    if(!defined($self->op_state)){
        $self->logger->error("No operational state specified yet!!");
        return { status => undef, error => {msg => "No operational status yet, probably not connected to device"}};
    }

    if(!defined($self->op_state->{'ports'}{$interface})){
        $self->logger->error("NO Port named: " . $interface);
        return { status => undef, error => {msg => "No interface was found by that name on the device"}};
    }

    return {status => $self->op_state->{'ports'}{$interface}{'status'}};
}

=head2 _gather_operational_status

=cut

sub _gather_operational_status{
    my $self = shift;

    my $operational_status = {ports => {}, vlans => {}};

    if ($self->device->connected) {
        my $interfaces = $self->device->get_interfaces();
        foreach my $interface (keys (%{$interfaces->{'interfaces'}})) {
            $self->logger->info("Found interface $interface.");
            $operational_status->{'ports'}->{$interface} = $interfaces->{'interfaces'}->{$interface};
        }

        my $vlans = $self->device->get_vlans();
        foreach my $vlan (@{$vlans}) {
            $self->logger->info("Found vlan $vlan->{'vlan'}.");
            $operational_status->{'vlans'}->{$vlan->{'vlan'}} = $vlan;
        }
    }

    $self->_set_op_state($operational_status);
}


=head2 start

=cut

sub start{
    my $self = shift;
    
    if(!defined($self->dispatcher)){
	$self->logger->error("Dispatcher is not connected");
    }else{
	$self->dispatcher->start_consuming();
	return;
    }
}

=head2 stop

=cut

sub stop{
    my $self = shift;
    $self->dispatcher->stop_consuming();
}

=head2 execute_command

=cut

sub execute_command{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    $self->logger->info("Calling execute_command");
    $self->logger->debug(Dumper($p_ref));

    if (!$self->device->connected) {
        return {success => 0, error => 1, error_msg => 'Device is currently disconnected.'};
    }

    my $in_configure = 0;
    my $in_context   = 0;
    my $prompt       = undef;

    if ($p_ref->{'config'}{'value'}) {
        $self->logger->debug('Trying to enter configure mode.');

        my $ok = $self->device->configure();
        if (!$ok) {
            my $err = "Couldn't enter configure mode.";
            $self->logger->error($err);
            return {success => 0, error => 1, error_msg => $err};
        }

        $in_configure = 1;
    }

    if (defined $p_ref->{'context'}{'value'}) {
        $self->logger->debug('Trying to enter context ' . $p_ref->{'context'}{'value'});

        my $ok = $self->device->set_context($p_ref->{'context'}{'value'});
        if (!$ok) {
            if ($in_configure) {
                $self->device->exit_configure();
            }

            my $err = "Couldn't enter desired context.";
            $self->logger->error($err);
            return {success => 0, error => 1, error_msg => $err};
        }

        $prompt = "#";
        $in_context = 1;
    }

    # OK. We are now ready to send our command and get the results!
    my ($result, $err) = $self->device->issue_command($p_ref->{'command'}{'value'}, $prompt);
    if (defined $err) {
        return {success => 0, error => 1, error_msg => $err};
    }

    if($in_context){
        $self->device->exit_context();
    }

    if($in_configure){
        $self->device->exit_configure();
    }

    if (defined $prompt) {
        return {success => 1, raw => "ok"};
    } else {
        return {success => 1, raw => $result};
    }
}

1;
