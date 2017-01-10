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

=back

=cut

sub BUILD{
    my ($self) = @_;
    
    my $logger = GRNOC::Log->get_logger("VCE::Services::Switch");
    $self->_set_logger($logger);    
    
    $self->_set_vce( VCE->new() );

    my $client = GRNOC::RabbitMQ::Client->new( user => $self->rabbit_mq->{'user'},
					       pass => $self->rabbit_mq->{'pass'},
					       host => $self->rabbit_mq->{'host'},
					       timeout => 30,
					       port => $self->rabbit_mq->{'port'},
					       exchange => 'VCE',
					       topic => 'VCE.Switch.RPC' );
    
    $self->_set_rabbit_client( $client );
    
    my $dispatcher = GRNOC::WebService::Dispatcher->new();

    $self->_set_template(Template->new());

    $self->_register_webservice_methods($dispatcher);

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
                
                $command->{'type'} = $type;

                warn Data::Dumper::Dumper($command);

                my $method = GRNOC::WebService::Method->new( name => $command->{'method_name'},
                                                             description => $command->{'description'},
                                                             callback => sub { 
                                                                 return $self->_execute_command($command, @_)
                                                             }); 

                $method->add_input_parameter( required => 1,
                                              name => 'workgroup',
                                              pattern => $GRNOC::WebService::Regex::NAME,
                                              description => "workgroup to run the command as" );

                if($type eq 'system' || $type eq 'port'){
                    warn "Adding required param switch!\n";
                    $method->add_input_parameter( required => 1,
                                                  name => 'switch',
                                                  pattern => $GRNOC::WebService::Regex::NAME,
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
                                                  pattern => $GRNOC::WebService::Regex::TEXT,
                                                  description => "the vlan to run the command for" );
                    
                }

                foreach my $param (keys %{$command->{'params'}}){
                    
                    $method->add_input_parameter( required => 1,
                                                  name => $param,
                                                  pattern => $command->{'params'}{$param}->{'pattern'},
                                                  description => $command->{'params'}{$param}->{'description'} );

                }

                $d->register_method( $method );

            }
        }
    }
}


sub _register_webservice_methods{
    my $self = shift;
    my $d = shift;

    my $method = GRNOC::WebService::Method->new(
	name => "get_interfaces",
	description => "returns a list of interfaces and the interfaces details",
	callback => sub{ return $self->get_interfaces(@_) });
    
    $method->add_input_parameter( name => "interface_name",
				  pattern => $GRNOC::WebService::Regex::NAME,
				  required => 0,
				  multiple => 1,
				  description => "Interface name to query");

    $d->register_method($method);
				  
}

=head2 get_interfaces

=cut

sub get_interfaces{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;
    
    my $interfaces = $self->rabbit_client->get_interfaces( interface_name => $p_ref->{'interface_name'}{'value'} )->{'results'};

    my @ints;
    foreach my $int (keys(%{$interfaces->{'interfaces'}})){
	push(@ints,$interfaces->{'interfaces'}{$int});
    }

    return {results => [{interfaces => \@ints, raw => $interfaces->{'raw'}}]};
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

    warn "IN EXECUTE COMMAND!!\n";

    $p_ref->{'command'} = $command;

    #first verify we have the permissions to execute this
    if(!$self->_authorize_command( %{$p_ref})){
        #ok you weren't authorized
        return {results => [], error => {msg => "Workgroup not authorized for command " . $command->{'name'} . " on switch " . $p_ref->{'switch'}{'value'}}};
    }
    
    #ok we are now authorized... run the command
    my $cmd_string;
    my $context_string;
    my $vars = {};;
    foreach my $var (keys %{$p_ref}){
        $vars->{$var} = $p_ref->{$var}{'value'};
    }

    if(defined($command->{'context'})){
        #some commands might not have context
        my $text = $command->{'context'};
        $self->template->process(\$text, $vars, \$context_string) or $self->logger->error("Error creating Context string");
        $self->logger->debug("Context String: " . $context_string);
    }

    my $text = $command->{'actual_command'};
    $self->template->process(\$text, $vars, \$cmd_string) or warn "Error creating template string: " . Dumper($self->template->error());# $self->logger->error("Error creating command string");
    warn Data::Dumper::Dumper($cmd_string);
    $self->logger->debug("Command String: " . $cmd_string);

    if(!defined($cmd_string)){
        return {results => [], error => {msg => "Error processing command"}};
    }

    my $res = $self->rabbit_client->execute_command( context => $context_string,
                                                 command => $cmd_string,
                                                 config => $command->{'config'} );

    if($res->{'error'}){
        return {success => 0, error => {msg => $res->{'error_message'}}};
    }else{
        return { success => 1, raw => $res->{'results'}};
    }

}

sub _authorize_command{
    my $self = shift;
    my %params = @_;

    warn "IN AUTHORIZE COMMAND\n";
    warn Dumper(%params);

    if($params{'command'}->{'type'} eq 'system'){
        if(scalar( $self->vce->get_available_ports( workgroup => $params{'workgroup'}{'value'}, switch => $params{'switch'}{'value'}) ) >= 0){
            return 1;
        }else{
            return 0;
        }
    }elsif($params{'command'}->{'type'} eq 'port'){
        if($self->access->workgroup_has_access_to_port( workgroup => $params{'workgroup'}{'value'},
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
