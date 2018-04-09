#!/usr/bin/perl

package VCE::Services::Switch;

use strict;
use warnings;

use Moo;
use GRNOC::Log;
use GRNOC::RabbitMQ::Client;
use GRNOC::WebService::Dispatcher;
use GRNOC::WebService::Method;
use GRNOC::WebService::Regex;

use VCE::Access;
use Template;

has vce => (is => 'rwp');
has logger => (is => 'rwp');
has rabbit_client => (is => 'rwp');
has dispatcher => (is => 'rwp');
has rabbit_mq => (is => 'rwp');
has template => (is => 'rwp');

=head2 BUILD

=over 4

=item access

=item dispatcher

=item logger

=item rabbit_client

=item rabbit_mq

=item template

=item vce

=back

=cut

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf', watch => 15);
    my $log    = $logger->get_logger("VCE::Services::Switch");
    $self->_set_logger($log);

    $self->_set_vce( VCE->new() );

    my $client = GRNOC::RabbitMQ::Client->new(
        user     => $self->rabbit_mq->{'user'},
        pass     => $self->rabbit_mq->{'pass'},
        host     => $self->rabbit_mq->{'host'},
        timeout  => 30,
        port     => $self->rabbit_mq->{'port'},
        exchange => 'VCE',
        topic    => 'VCE.Switch.'
    );
    $self->_set_rabbit_client($client);

    my $dispatcher = GRNOC::WebService::Dispatcher->new();

    $self->_set_template(Template->new());

    $self->_register_commands($dispatcher);

    $self->_set_dispatcher($dispatcher);

    return $self;
}

sub _register_commands{
    my $self = shift;
    my $d = shift;

    my $list_of_commands = {};

    my $switches = $self->vce->get_all_switches();

    foreach my $switch (@$switches){
        my $commands = $switch->{'commands'};
        foreach my $type (keys (%{$commands})){
            foreach my $command (@{$commands->{$type}}){
                $command->{'cli_type'} = $command->{'type'};
                $command->{'type'}     = $type;

                my $method = GRNOC::WebService::Method->new( name => $command->{'method_name'},
                                                             description => $command->{'description'},
                                                             callback => sub {
                                                                 return $self->_execute_command($command, @_)
                                                             });

                $method->add_input_parameter( required => 1,
                                              name => 'workgroup',
                                              pattern => $GRNOC::WebService::Regex::NAME_ID,
                                              description => "workgroup to run the command as" );

                if($type eq 'system' || $type eq 'port' || $type eq 'vlan'){
                    warn "Adding required param switch!\n";
                    $method->add_input_parameter( required => 1,
                                                  name => 'switch',
                                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                                  description => "Switch to run the command on" );
                }

                if($type eq 'port'){
                    $method->add_input_parameter( required => 1,
                                                  name => "port",
                                                  pattern => "(.*)",
                                                  description => "the port to run the command on");
                }

                if($type eq 'vlan'){
                    $method->add_input_parameter( required => 1,
                                                  name => 'vlan_id',
                                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                                  description => "the vlan to run the command for" );
                }

                foreach my $param (keys %{$command->{'params'}}){
                    $method->add_input_parameter( required => 1,
                                                  name => $param,
                                                  pattern => $command->{'params'}{$param}->{'pattern'},
                                                  description => $command->{'params'}{$param}->{'description'} );
                }

                eval {
                    $d->register_method($method);
                };
                if ($@) {
                    # Because it's possible (likely) that multiple
                    # switches have the same command definition, we
                    # attempt to register the same command multiple
                    # times. Ignore when this happens and continue on.
                }
            }
        }
    }
}

=head2 handle_request

=cut

sub handle_request{
    my $self = shift;
    
    $self->dispatcher->handle_request();
}

sub _execute_command{
    my $self = shift;
    my $command = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    $p_ref->{'command'} = $command;
    $self->logger->debug("In _execute_command");

    # Verify we have the permissions to execute this
    if(!$self->_authorize_command( %{$p_ref})){
        my $err = "Workgroup not authorized for command " . $command->{'name'} . " on switch " . $p_ref->{'switch'}{'value'};
        $self->logger->error($err);
        return {results => [], error => {msg => $err}};
    }

    my $cmd_string;
    my $context_string;
    my $vars = {};
    foreach my $var (keys %{$p_ref}){
        $vars->{$var} = $p_ref->{$var}{'value'};

        # The frontend uses a uuid to identify a (pair of vlans ||
        # circuit || network). This should be a valid vlan number.
        if ($var eq 'vlan_id') {
            my $vlan = $self->vce->network_model->get_vlan_details( vlan_id => $vars->{'vlan_id'} );
            $vars->{'vlan_id'} = $vlan->{'vlan'};
        }
    }

    if(defined($command->{'context'})){
        #some commands might not have context
        my $text = $command->{'context'};
        $self->template->process(\$text, $vars, \$context_string) or $self->logger->error("Error creating Context string");
        $self->logger->debug("Context String: " . $context_string);
    }

    my $text = $command->{'actual_command'};

    # Old template->process failure handler
    # or warn "Error creating template string: " . Dumper($self->template->error());
    $self->template->process(\$text, $vars, \$cmd_string) or $self->logger->error("Error creating command template: " . Dumper($self->template->error()));

    if(!defined($cmd_string)){
        return {results => [], error => {msg => "Error processing command"}};
    }

    if (!defined $command->{'configure'} || $command->{'configure'} ne 'true') {
        $command->{'configure'} = 0;
    } else {
        $command->{'configure'} = 1;
    }

    $self->logger->debug("Running $cmd_string with params: " . Dumper($vars));
    $self->rabbit_client->{topic} = 'VCE.Switch.' . $p_ref->{switch}{value};

    my $res;
    if (defined $context_string) {
        $self->logger->debug("Running $cmd_string in context $context_string: " . Dumper($command));
        $res = $self->rabbit_client->execute_command( context => $context_string,
                                                      command => $cmd_string,
                                                      config => $command->{'configure'},
                                                      cli_type => $command->{'cli_type'} );
    } else {
        $self->logger->debug("Running $cmd_string with no context: " . Dumper($command));
        $res = $self->rabbit_client->execute_command( command => $cmd_string,
                                                      config => $command->{'configure'},
                                                      cli_type => $command->{'cli_type'} );
    }

    if ($res->{'results'}->{'error'}) {
        return {success => 0, error => {msg => $res->{'results'}->{'error_message'}}};
    } else {
        return { success => 1, raw => $res->{'results'}->{'raw'}};
    }
}

sub _authorize_command{
    my $self = shift;
    my %params = @_;

    warn "IN AUTHORIZE COMMAND\n";
    warn Dumper(%params);

    if($params{'command'}->{'type'} eq 'system'){
        my $ports = $self->vce->get_available_ports( workgroup => $params{'workgroup'}{'value'}, switch => $params{'switch'}{'value'});
        if(scalar @{$ports} >= 0){
            $self->logger->debug("Ports detected.");
            return 1;
        }else{
            $self->logger->debug("More than one port detected.");
            return 0;
        }
    }elsif($params{'command'}->{'type'} eq 'port'){
        if($self->vce->access->workgroup_has_access_to_port( workgroup => $params{'workgroup'}{'value'},
                                                        switch => $params{'switch'}{'value'},
                                                        port => $params{'port'}{'value'})){
            return 1;
        }else{
            return 0;
        }

    }elsif($params{'command'}->{'type'} eq 'vlan'){
        my $vlan = $self->vce->network_model->get_vlan_details( vlan_id => $params{'vlan_id'}{'value'} );
        if(!defined($vlan)){
            return 0;
        }
        if($vlan->{'workgroup'} eq $params{'workgroup'}{'value'}){
            return 1;
        }else{
            return 0;
        }
    
    }else{
        return 0;
    }
    
}


1;
