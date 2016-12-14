#!/usr/bin/perl

package VCE::Services::Access;

use strict;
use warnings;

use Moo;

use VCE;

use GRNOC::Log;
use GRNOC::RabbitMQ::Client;
use GRNOC::WebService::Dispatcher;
use GRNOC::WebService::Method;
use GRNOC::WebService::Regex;

has vce=> (is => 'rwp');
has logger => (is => 'rwp');
has dispatcher => (is => 'rwp');
has switch => (is => 'rwp');

has config_file => (is => 'rwp', default => '/etc/vce/access_policy.xml');
has network_model_file => (is => 'rwp', default => '/var/run/vce/network_model.json');
has rabbit_mq => (is => 'rwp');

=head2 BUILD

=cut

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE::Services::Switch");
    $self->_set_logger($logger);

    $self->_set_vce( VCE->new( config_file => $self->config_file,
                               network_model_file => $self->network_model_file  ) );

    $self->_set_switch( GRNOC::RabbitMQ::Client->new( user => $self->rabbit_mq->{'user'},
						      pass => $self->rabbit_mq->{'pass'},
						      host => $self->rabbit_mq->{'host'},
						      timeout => 30,
						      port => $self->rabbit_mq->{'port'},
						      exchange => 'VCE',
						      topic => 'VCE.Switch.RPC' ));

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
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");
    
    $d->register_method($method);


    $method = GRNOC::WebService::Method->new(
        name => "get_switches",
        description => "returns a list of switches available to a user and workgroup",
        callback => sub{ return $self->get_switches(@_) });

    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");
    
    $d->register_method($method);

    $method = GRNOC::WebService::Method->new(
        name => "get_ports",
        description => "returns a list of available ports on a switch",
	callback => sub{ return $self->get_ports(@_) });
    
    $method->add_input_parameter( name => "workgroup",
				  pattern => $GRNOC::WebService::Regex::NAME,
				  required => 1,
                                  multiple => 0,
				  description => "Workgroup name");

    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 1,
                                  multiple => 0,
				  description => "Switch to get ports from");
    
    $method->add_input_parameter( name => "port",
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 0,
                                  multiple => 1,
                                  description => "Individual name of a port to get details about");

    $d->register_method($method);

    $method = GRNOC::WebService::Method->new(
        name => "get_ports_tags",
        description => "returns a list of available tags on a port",
        callback => sub{ return $self->get_tags_on_ports(@_) });
    
    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");
    
    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME,
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
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");

    $method->add_input_parameter( name => "switch",
                                  pattern => $GRNOC::WebService::Regex::NAME,
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
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");
    
    $d->register_method($method);

    $method = GRNOC::WebService::Method->new(
        name => "get_vlan_details",
        description => "returns the details of a vlan",
        callback => sub{ return $self->get_vlan_details(@_) });

    $method->add_input_parameter( name => "workgroup",
                                  pattern => $GRNOC::WebService::Regex::NAME,
                                  required => 1,
                                  multiple => 0,
                                  description => "Workgroup name");

    $method->add_input_parameter( name => "vlan_id",
                                  pattern => $GRNOC::WebService::Regex::TEXT,
                                  required => 1,
                                  multiple => 0,
                                  description => "VLAN ID");

    $d->register_method($method);

}

=head2 handle_request

=cut

sub handle_request{
    my $self = shift;

    $self->vce->refresh_state();

    $self->dispatcher->handle_request();
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
        
        return {results => [workgroup => $obj]};
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
        my $switch_ports = $self->switch->get_interfaces(interface_name => $ports);

        foreach my $port (@{$p}) {
            $port->{'data'} = $switch_ports->{'results'}->{$port->{'port'}};
        }
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
	    push(@results, {port => $port, tags => $tags});
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

    if($self->vce->access->user_in_workgroup( username => $user,
                                              workgroup => $workgroup )){
        
        my $vlans = $self->vce->network_model->get_vlans( workgroup => $workgroup);
        return {results => [{vlans => $vlans}]};
    }else{
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }

}

=head2 get_vlan_details

=cut

sub get_vlan_details{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $p_ref->{'workgroup'}{'value'};

    if($self->vce->access->user_in_workgroup( username => $user,
                                              workgroup => $workgroup )){

        my $vlan = $self->vce->network_model->get_vlan_details( vlan_id => $p_ref->{'vlan_id'}{'value'});
        if($vlan->{'workgroup'} eq $workgroup){
            return {results => [{circuit => $vlan}]};
        }else{
            return {error => {'msg' => "Workgroup $workgroup does not have access to vlan " . $p_ref->{'vlan_id'}{'value'}}};
        }
    }else{
        return {results => [], error => {msg => "User $user not in specified workgroup $workgroup"}};
    }
}

1;
