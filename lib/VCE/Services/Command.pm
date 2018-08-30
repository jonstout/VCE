#!/usr/bin/perl

package VCE::Services::Command;

use strict;
use warnings;

use Moo;
use GRNOC::Log;
use GRNOC::RabbitMQ::Client;
use GRNOC::WebService::Dispatcher;
use GRNOC::WebService::Method;
use GRNOC::WebService::Regex;

use VCE::Access;
use VCE::Database::Connection;
use Template;

has vce => (is => 'rwp');
has db => (is => 'rwp');
has logger => (is => 'rwp');
has rabbit_client => (is => 'rwp');
has dispatcher => (is => 'rwp');
has rabbit_mq => (is => 'rwp');
has template => (is => 'rwp');

=head2 BUILD

=over 4

=item access

=item db

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
    my $log    = $logger->get_logger("VCE::Services::Command");
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
    $self->_set_db(VCE::Database::Connection->new('/var/lib/vce/database.sqlite'));

    $self->_set_template(Template->new());

    $self->_register_commands($dispatcher);

    $self->_register_methods($dispatcher);

    $self->_set_dispatcher($dispatcher);

    return $self;
}

sub _register_methods{
    my $self = shift;
    my $dispatcher = shift;

    my $method = GRNOC::WebService::Method->new( name => 'get_commands',
						 description => 'get a list of commands and the details of those commands',
						 callback => sub { return $self->get_commands(@_); }
	);

    $method->add_input_parameter(
	required => 0,
	name => 'command_id',
	pattern => $GRNOC::WebService::Regex::NUMBER_ID,
	description => "command_id to fetch");

    $dispatcher->register_method($method);

    $method = GRNOC::WebService::Method->new( name => 'add_command',
					      description => 'adds a new command to the list of commands',
					      callback => sub { return $self->add_command(@_); }
	);

    $method->add_input_parameter(
	required => 1,
	name => 'name',
	pattern => $GRNOC::WebService::Regex::NAME_ID,
	description => "name of the command to be added"
	);

    $method->add_input_parameter(
	required => 1,
	name => 'description',
	pattern => $GRNOC::WebService::Regex::TEXT,
	description => "friendly description of the command"
	);

    $method->add_input_parameter(
	required => 1,
	name => 'operation',
	pattern => "(read|write)",
	description => "What type of operation is this 'read' or 'write'"
	);

    $method->add_input_parameter(
	required => 1,
	name => 'type',
	pattern => "(interface|switch|vlan)",
	description => "which class of VCE type is this command acting on 'interface', 'switch', or 'vlan'"
	);

    $method->add_input_parameter(
	required => 1,
	name => 'template',
	pattern => $GRNOC::WebService::Regex::TEXT,
	description => "workgroup to run the command as"
	);

    $dispatcher->register_method($method);

    $method = GRNOC::WebService::Method->new( name => 'modify_command',
                                              description => 'modifies and existing command',
					      callback => sub { return $self->modify_command(@_); }
	);

    $method->add_input_parameter(
        required => 1,
        name => 'command_id',
        pattern => $GRNOC::WebService::Regex::NUMBER_ID,
        description => "ID of the command to be modified"
	);

    $method->add_input_parameter(
        required => 0,
        name => 'name',
        pattern => $GRNOC::WebService::Regex::NAME_ID,
        description => "name of the command to be modified"
        );

    $method->add_input_parameter(
        required => 0,
        name => 'description',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "description of the command"
        );

    $method->add_input_parameter(
        required => 0,
        name => 'operation',
        pattern => "(read|write)",
        description => "Operation type 'read' or 'write'"
        );

    $method->add_input_parameter(
        required => 0,
        name => 'type',
        pattern => "(interface|switch|vlan)",
        description => "which class of VCE type is this command acting on 'interface', 'switch', or 'vlan'"
        );


    $dispatcher->register_method($method);

    $method = GRNOC::WebService::Method->new( name => 'delete_command',
                                              description => 'deletes and existing command',
					      callback => sub { return $self->delete_command(@_); }
	);

    $method->add_input_parameter(
        required => 1,
        name => 'command_id',
        pattern => $GRNOC::WebService::Regex::NUMBER_ID,
        description => "ID of the command to be deleted"
        );

    $dispatcher->register_method($method);
}

sub _register_commands{
    my $self = shift;
    my $d = shift;

    my $list_of_commands = {};

    my $switches = $self->vce->get_all_switches();

    foreach my $switch (@$switches) {

        my $commands = $self->db->get_commands(switch_id => $switch->{id});
        foreach my $command (@$commands) {
            $command->{'cli_type'} = 'action';
            my $type = $command->{type};
            my $name = $command->{name};
            $name =~ tr/ //ds;

            my $method = GRNOC::WebService::Method->new(
                name => $name,
                description => $command->{'description'},
                callback => sub { return $self->_execute_command($command, @_) }
            );
            $method->add_input_parameter(
                required => 1,
                name => 'workgroup',
                pattern => $GRNOC::WebService::Regex::NAME_ID,
                description => "workgroup to run the command as"
            );
            $method->add_input_parameter(
                required => 1,
                name => 'switch',
                pattern => $GRNOC::WebService::Regex::NAME_ID,
                description => "Switch to run the command on"
            );

            if($type eq 'interface'){
                $method->add_input_parameter(
                    required => 1,
                    name => "port",
                    pattern => "(.*)",
                    description => "the port to run the command on"
                );
            }

            if($type eq 'vlan'){
                $method->add_input_parameter(
                    required => 1,
                    name => 'vlan_id',
                    pattern => $GRNOC::WebService::Regex::NAME_ID,
                    description => "the vlan to run the command for"
                );
            }

            my $params = $self->db->get_parameters(command_id => $command->{command_id});
            foreach my $param (@$params) {
                $method->add_input_parameter(
                    required => 1,
                    name => $param->{name},
                    pattern => $param->{regex},
                    description => $param->{description}
                );
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
warn "authorized";
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
warn 'checked for vlan_id';
    if(defined($command->{'context'})){
        #some commands might not have context
        my $text = $command->{'context'};
        $self->template->process(\$text, $vars, \$context_string) or $self->logger->error("Error creating Context string");
        $self->logger->debug("Context String: " . $context_string);
    }

    my $text = $command->{'template'};

    # Old template->process failure handler
    # or warn "Error creating template string: " . Dumper($self->template->error());
    $self->template->process(\$text, $vars, \$cmd_string) or $self->logger->error("Error creating command template: " . Dumper($self->template->error()));
warn "made template $cmd_string";
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
warn 'sending command to switch';
warn 'VCE.Switch.' . $p_ref->{switch}{value};
    my $res;
    if (defined $context_string) {
        $self->logger->debug("Running $cmd_string in context $context_string: " . Dumper($command));
        $res = $self->rabbit_client->execute_command( context => $context_string,
                                                      command => $cmd_string,
                                                      # config => $command->{'configure'},
                                                      config => 0,
                                                      cli_type => $command->{'role'} );
    } else {
        $self->logger->debug("Running $cmd_string with no context: " . Dumper($command));
        $res = $self->rabbit_client->execute_command( command => $cmd_string,
                                                      # config => $command->{'configure'},
                                                      config => 0,
                                                      cli_type => $command->{'role'} );
    }
warn Dumper($res);
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
return 1;

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

sub get_commands{
    my $self = shift;
    my $method_ref = shift;
    my $p_ref = shift;

    my %params;
    if(defined($p_ref->{'command_id'}{'value'})){
        $params{'command_id'} = $p_ref->{'command_id'}{'value'};
    }
    if(defined($p_ref->{'type'}{'value'})){
        $params{'type'} = $p_ref->{'type'}{'value'};
    }

    my $commands = $self->db->get_commands( %params );
    return {results => $commands };
}

sub add_command{
    my $self = shift;
    my $method_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};

    if (!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup )) {
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my $name = $p_ref->{'name'}{'value'};
    my $description = $p_ref->{'description'}{'value'};
    my $operation = $p_ref->{'operation'}{'value'};
    my $type = $p_ref->{'type'}{'value'};
    my $template = $p_ref->{'template'}{'value'};
    my $res = $self->db->add_command( $name, $description, $operation, $type, $template );

    return {results => [{id => $res}]};
}

sub modify_command{
    my $self = shift;
    my $method_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};

    if(!$self->vce->access->user_in_workgroup( username => $user,
					       workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my $name = $p_ref->{'name'}{'value'};
    my $description = $p_ref->{'description'}{'value'};
    my $operation = $p_ref->{'operation'}{'value'};
    my $type = $p_ref->{'type'}{'value'};
    my $template = $p_ref->{'template'}{'value'};
    my $command_id = $p_ref->{'command_id'}{'value'};

    my $res = $self->db->modify_command( name => $name, description => $description, operation => $operation, type => $type, template => $template, command_id => $command_id );
    if($res eq "0E0"){
        $method_ref->set_error("Update failed for command: " . $command_id);
        return;
    }
    return {results => [{value => $res}]};
}

sub delete_command{
    my $self = shift;
    my $method_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};

    if (!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup )) {
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my $res = $self->db->delete_command($p_ref->{'command_id'}{'value'});
    if($res eq "0E0"){
        $method_ref->set_error("Delete failed for command: " . $p_ref->{'command_id'}{'value'});
        return;
    }
    return {results => [{ value => $res}]};
}

1;
