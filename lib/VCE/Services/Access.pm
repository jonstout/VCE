#!/usr/bin/perl

package VCE::Services::Access;

use strict;
use warnings;

use Moo;
use Data::Dumper;
use VCE;

use GRNOC::Log;
use GRNOC::RabbitMQ;
use GRNOC::WebService::Dispatcher;
use GRNOC::WebService::Method;
use GRNOC::WebService::Regex;

has vce=> (is => 'rwp');
has logger => (is => 'rwp');
has dispatcher => (is => 'rwp');

has config_file => (is => 'rwp', default => '/etc/vce/access_policy.xml');
has network_model_file => (is => 'rwp', default => '/var/run/vce/network_model.json');

=head2 BUILD

=over 4

=item config_file

=item logger

=item dispatcher

=item network_model

=item vce

=item network_model_file

=back

=cut

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE::Services::Switch");
    $self->_set_logger($logger);

    $self->_set_vce( VCE->new( config_file => $self->config_file,
                               network_model_file => $self->network_model_file  ) );

    my $dispatcher = GRNOC::WebService::Dispatcher->new();

    $self->_register_webservice_methods($dispatcher);

    $self->_set_dispatcher($dispatcher);

    return $self;
}

sub _register_webservice_methods{
    my $self = shift;
    my $d = shift;

    my $method = GRNOC::WebService::Method->new(
        name => "get_workgroups",
        description => "returns a list of workgroups available to a user",
        callback => sub{ return $self->get_workgroups(@_) });

    $d->register_method($method);

    $method = GRNOC::WebService::Method->new(
        name => "get_workgroup_details",
        description => "returns the details of a workgroup",
        callback => sub{ return $self->get_workgroup_details(@_) });
    
    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");
    
    $d->register_method($method);


    $method = GRNOC::WebService::Method->new(
        name => "get_switches",
        description => "returns a list of switches available to a user and workgroup",
        callback => sub{ return $self->get_switches(@_) });

    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");
    
    $d->register_method($method);

    $method = GRNOC::WebService::Method->new(
        name => "get_ports",
        description => "returns a list of available ports on a switch",
	callback => sub{ return $self->get_ports(@_) });
    
    $method->add_input_parameter( name => "workgroup",
				  pattern => $GRNOC::WebService::Regex::NAME_ID,
				  required => 1,
                                  multiple => 0,
				  description => "Workgroup name");

    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
				  description => "Switch to get ports from");
    
    $method->add_input_parameter( name => "port",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 0,
                                  multiple => 1,
                                  description => "Individual name of a port to get details about");

    $d->register_method($method);

    $method = GRNOC::WebService::Method->new(
        name => "get_ports_tags",
        description => "returns a list of available tags on a port",
        callback => sub{ return $self->get_tags_on_ports(@_) });
    
    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");
    
    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Switch to get ports from");

    $method->add_input_parameter( name => "port",
                                  pattern => "(.*)",
                                  required => 0,
                                  multiple => 1,
                                  description => "Individual name of a port to get details about");

    $d->register_method($method);

    $method = GRNOC::WebService::Method->new(
        name => "is_tag_available",
        description => "returns if a tag is available or not",
        callback => sub{ return $self->is_tag_available(@_) });
    
    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");

    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Switch to get ports from");

    $method->add_input_parameter( name => "port",
                                  pattern => "(.*)",
                                  required => 1,
                                  multiple => 0,
                                  description => "Switch to get ports from");

    $method->add_input_parameter( name => "tag",
                                  pattern => $GRNOC::WebService::Regex::NUMBER,
                                  required => 1,
                                  multiple => 0,
                                  description => "VLAN Tag to check for availability");

    $d->register_method($method);


    $method = GRNOC::WebService::Method->new(
        name => "get_vlans",
        description => "returns a list of vlans",
        callback => sub{ return $self->get_vlans(@_) });
    
    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");
    
    $d->register_method($method);

    $method = GRNOC::WebService::Method->new(
        name => "get_vlan_details",
        description => "returns the details of a vlan",
        callback => sub{ return $self->get_vlan_details(@_) });

    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");

    $method->add_input_parameter( name => "vlan_id",
                                  pattern => $GRNOC::WebService::Regex::TEXT,
                                  required => 1,
                                  multiple => 0,
                                  description => "VLAN ID");

    $d->register_method($method);


    $method = GRNOC::WebService::Method->new(
        name => "get_switch_commands",
        description => "returns the commands that can be run on a switch",
        callback => sub{ return $self->get_switch_commands(@_) });

    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");

    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Switch to get the commands that can be run");

    $d->register_method($method);


    $method = GRNOC::WebService::Method->new(
        name => "get_port_commands",
        description => "returns the commands that can be run on a vlan",
        callback => sub{ return $self->get_port_commands(@_) });
    
    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");
    
    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Switch to get the commands that can be run");
    

    $d->register_method($method);

    $method = GRNOC::WebService::Method->new(
        name => "get_vlan_commands",
        description => "returns the commands that can be run on a vlan",
        callback => sub{ return $self->get_vlan_commands(@_) });

    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");

    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME_ID,
                                  required => 1,
                                  multiple => 0,
                                  description => "port to get the commands that can be run");


    $d->register_method($method);
}

=head2 handle_request

=cut

sub handle_request{
    my $self = shift;

    $self->vce->refresh_state();

    $self->dispatcher->handle_request();
}


=head2 get_switch_commands

=cut

sub get_switch_commands{
    my $self = shift;
    my $method_ref = shift;
    my $p_ref = shift;

    my $workgroup = $p_ref->{'workgroup'}{'value'};

    my $user = $ENV{'REMOTE_USER'};

    my $switch = $p_ref->{'switch'}{'value'};
    if($self->vce->access->user_in_workgroup( username => $user,
                                              workgroup => $workgroup)){

	if(scalar($self->vce->get_available_ports( workgroup => $workgroup, switch => $switch)) >= 1){
            my $switch_commands = $self->vce->access->get_switch_commands( switch => $switch );
            my @results;
            foreach my $cmd (@$switch_commands){
                my $obj = {};
                $obj->{'method_name'} = $cmd->{'method_name'};
                $obj->{'name'} = $cmd->{'name'};
                $obj->{'parameters'} = ();
                $obj->{'type'} = $cmd->{'type'};
                push(@{$obj->{'parameters'}}, { type => 'hidden',
                                                name => 'workgroup',
                                                description => "workgroup to run the command as",
                                                required => 1 });

                push(@{$obj->{'parameters'}}, { type => 'hidden',
                                                name => 'switch',
                                                description => "switch to run the command on",
                                                required => 1 });

                foreach my $param (keys (%{$cmd->{'params'}})){
                    
                    my $p = {};
                    
                    if($cmd->{'parameters'}{$param}{'type'} eq 'select'){
                        @{$p->{'options'}} = split(',',$cmd->{'params'}{$param}{'options'});
                    }else{
                        
                    }
                    $p->{'type'} = $cmd->{'params'}{$param}{'type'};
                    $p->{'name'} = $param;
                    $p->{'description'} = $cmd->{'params'}{$param}{'description'};
                    $p->{'required'} = 1;
                    push(@{$obj->{'parameters'}}, $p);
                }

                push(@results, $obj);
            }

	    return {results => \@results};
	}else{
	    return {results => [], error => {msg => "Workgroup not authorized for switch $switch"}};
	}
    }else{
	return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }
}

=head2 get_port_commands

=cut

sub get_port_commands{
    my $self = shift;
    my $method_ref = shift;
    my $p_ref = shift;
    
    my $workgroup = $p_ref->{'workgroup'}{'value'};
    
    my $user = $ENV{'REMOTE_USER'};
    
    my $switch = $p_ref->{'switch'}{'value'};
    
    if($self->vce->access->user_in_workgroup( username => $user,
                                              workgroup => $workgroup)){
        
        my $ports = $self->vce->get_available_ports( workgroup => $workgroup, switch => $switch);
        if(scalar($ports) >= 0){
            my $switch_commands = $self->vce->access->get_port_commands( switch => $switch, port => $ports->[0] );
            my @results;
            foreach my $cmd (@$switch_commands){
                my $obj = {};
                $obj->{'method_name'} = $cmd->{'method_name'};
                $obj->{'name'} = $cmd->{'name'};
                $obj->{'type'} = $cmd->{'type'};
                $obj->{'parameters'} = ();
                
                push(@{$obj->{'parameters'}}, { type => 'hidden',
                                                name => 'workgroup',
                                                description => "workgroup to run the command as",
                                                required => 1 });
                
                push(@{$obj->{'parameters'}}, { type => 'hidden',
                                                name => 'switch',
                                                description => "switch to run the command on",
                                                required => 1 });
                
                push(@{$obj->{'parameters'}}, { type => 'hidden',
                                                name => 'port',
                                                description => "port to run the command on",
                                                required => 1 });
                
                foreach my $param (keys (%{$cmd->{'params'}})){
                    warn Dumper($cmd->{'params'}{$param});
                    my $p = {};
                    
                    if($cmd->{'params'}{$param}{'type'} eq 'select'){
                        @{$p->{'options'}} = split(',',$cmd->{'params'}{$param}{'options'});
                    }else{
                        
                    }
                    $p->{'type'} = $cmd->{'params'}{$param}{'type'};
                    $p->{'name'} = $param;
                    $p->{'description'} = $cmd->{'params'}{$param}{'description'};
                    $p->{'required'} = 1;
                    push(@{$obj->{'parameters'}}, $p);
                }
                
                push(@results, $obj);
            }
            
            return {results => \@results};
        }else{
            return {results => [], error => {msg => "Workgroup not authorized for switch $switch"}};
        }
    }else{
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }
}

=head2 get_vlan_commands

Returns the commands that are configured related to vlans.

=cut
sub get_vlan_commands{
    my $self = shift;
    my $method_ref = shift;
    my $p_ref = shift;

    my $switch = $p_ref->{'switch'}{'value'};
    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $user = $ENV{'REMOTE_USER'};

    my $in_workgroup = $self->vce->access->user_in_workgroup(
        username => $user,
        workgroup => $workgroup
    );
    if (!$in_workgroup) {
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }

	my $switch_commands = $self->vce->access->get_vlan_commands( switch => $switch );
    my @results;
    foreach my $cmd (@$switch_commands){
        my $obj = {};
        $obj->{'method_name'} = $cmd->{'method_name'};
        $obj->{'name'} = $cmd->{'name'};
        $obj->{'parameters'} = ();
        $obj->{'type'} = $cmd->{'type'};
        push(@{$obj->{'parameters'}}, { type => 'hidden',
                                        name => 'workgroup',
                                        description => "workgroup to run the command as",
                                        required => 1 });

        push(@{$obj->{'parameters'}}, { type => 'hidden',
                                        name => 'vlan_id',
                                        description => "vlan_id of the vlan to run the command on",
                                        required => 1 });

        foreach my $param (keys (%{$cmd->{'params'}})){
            my $p = {};

            if($cmd->{'params'}{$param}{'type'} eq 'select'){
                @{$p->{'options'}} = split(',',$cmd->{'params'}{$param}{'options'});
            }else{

            }

            $p->{'type'} = $cmd->{'params'}{$param}{'type'};
            $p->{'name'} = $param;
            $p->{'description'} = $cmd->{'params'}{$param}{'description'};
            $p->{'required'} = 1;

            push(@{$obj->{'parameters'}}, $p);
        }
        push(@results, $obj);
    }

    return {results => \@results};
}

=head2 get_workgroups

=cut

sub get_workgroups{
    my $self = shift;

    my $user = $ENV{'REMOTE_USER'};
    
    $self->logger->debug("Fetching workgroups for user: " . $user);
    return {results => [{workgroups => $self->vce->get_workgroups( username => $user )}]};
}

=head2 get_workgroup_details

=cut

sub get_workgroup_details{
    my $self = shift;
    my $method_ref = shift;
    my $p_ref = shift;
    
    my $workgroup = $p_ref->{'workgroup'}{'value'};

    my $user = $ENV{'REMOTE_USER'};

    if($self->vce->access->user_in_workgroup( username => $user,
                                              workgroup => $workgroup)){

        my $obj = $self->vce->get_workgroup_details( workgroup => $workgroup);
        
        return {results => [$obj]};
    }else{
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }

}

=head2 get_ports

=cut

sub get_ports{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;
    
    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $switch = $p_ref->{'switch'}{'value'};
    my $ports = $p_ref->{'port'}{'value'};

    #verify user in workgroup
    if($self->vce->access->user_in_workgroup( username => $user,
					      workgroup => $workgroup )){
	
	my $p = $self->vce->get_available_ports( workgroup => $workgroup, switch => $switch, ports => $ports);
	return {results => [{ ports => $p}]};
    }else{
	return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }
}

=head2 get_tags_on_ports

=cut

sub get_tags_on_ports{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $switch = $p_ref->{'switch'}{'value'};
    my $ports = $p_ref->{'port'}{'value'};
    
    #verify user in workgroup
    if($self->vce->access->user_in_workgroup( username => $user,
					      workgroup => $workgroup )){
	
	my @results;
	foreach my $port (@$ports){
	    my $tags = $self->vce->get_tags_on_port( workgroup => $workgroup, switch => $switch, port => $port);
	    #push(@results, {port => $port, tags => $tags});
            push(@results, {port => $port, tags => $self->vce->access->friendly_display_vlans($tags)});
	}
	return {results => [{ports => \@results}]};
    }else{
	return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }
}


=head2 is_tag_available

=cut

sub is_tag_available{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};
    
    my $workgroup = $p_ref->{'workgroup'}{'value'};
    my $switch = $p_ref->{'switch'}{'value'};
    my $port = $p_ref->{'port'}{'value'};
    my $tag = $p_ref->{'tag'}{'value'};

    warn "Is tag available\n";

    #verify user in workgroup
    if($self->vce->access->user_in_workgroup( username => $user,
                                              workgroup => $workgroup )){
        warn "USer is in workgroup\n";
	
        #first verify user has access to switch/port/tag
        if($self->vce->access->workgroup_has_access_to_port( workgroup => $workgroup,
                                                             switch => $switch, 
                                                             port => $port,
                                                             vlan => $tag)){
            
            warn "workgroup has access to port and vlan\n";
            my $tag_avail = $self->vce->is_tag_available( switch => $switch, port => $port, tag => $tag);
            return {results => [{ available => $tag_avail}]};
        }else{
            return {results => [{ available => 0}], error => {msg => "Workgroup $workgroup is not allowed tag $tag on $switch:$port"}};
        }
    }else{
	return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }
}

=head2 get_switches

=cut


sub get_switches{
    my $self = shift;

    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};

    if($self->vce->access->user_in_workgroup( username => $user,
                                              workgroup => $workgroup )){

        my $switches = $self->vce->get_switches( workgroup => $workgroup);

        return {results => [{switch => $switches}]};
    }else{
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }
}

=head2 get_vlans

=cut
sub get_vlans{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};

    if (!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup)) {
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }

    my $vlans = $self->vce->network_model->get_vlans();

    my @vlans;
    foreach my $vlan (@$vlans) {
        my $vlan_details = $self->vce->network_model->get_vlan_details(vlan_id => $vlan);
        # Check if the VLAN is owned by $workgroup.
        if ($vlan_details->{'workgroup'} eq $workgroup) {
            push(@vlans, $vlan_details);
            next;
        }

        # Check if an Endpoint on the VLAN is owned by $workgroup.
        foreach my $endpoint (@{$vlan_details->{'endpoints'}}) {
            my $ok = $self->vce->access->workgroup_has_access_to_port(
                workgroup => $workgroup,
                switch    => $vlan_details->{'switch'},
                port      => $endpoint->{'port'},
                vlan      => $vlan_details->{'vlan'}
            );
            if ($ok) {
                push(@vlans, $vlan_details);
                last;
            }
        }
    }

    return {results => [{vlans => \@vlans}]};
}

=head2 get_vlan_details

=cut
sub get_vlan_details{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};

    my $valid_workgroup = $self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup);
    if (!$valid_workgroup) {
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }

    my $vlan = $self->vce->network_model->get_vlan_details(vlan_id => $p_ref->{'vlan_id'}{'value'});

    my $workgroup_owns_vlan = $vlan->{'workgroup'} eq $workgroup;
    my $workgroup_owns_port = 0;

    # Check if an Endpoint on the VLAN is owned by $workgroup.
    foreach my $endpoint (@{$vlan->{'endpoints'}}) {
        my $ok = $self->vce->access->workgroup_has_access_to_port(
            workgroup => $workgroup,
            switch    => $vlan->{'switch'},
            port      => $endpoint->{'port'},
            vlan      => $vlan->{'vlan'}
        );
        if ($ok) {
            $workgroup_owns_port = 1;
            last;
        }
    }

    if ($workgroup_owns_vlan || $workgroup_owns_port) {
        return {results => [{circuit => $vlan}]};
    }

    my $error = "Workgroup $workgroup does not have access to vlan " . $p_ref->{'vlan_id'}{'value'};
    $self->logger->error($error);
    return {error => {'msg' => $error}};
}

1;
