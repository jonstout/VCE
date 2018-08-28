#!/usr/bin/perl

package VCE::Services::Interface;

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
has logger => (is => 'rwp');
has dispatcher => (is => 'rwp');
has template => (is => 'rwp');
has db => (is => 'rwp');

=head2 BUILD

=over 4

=item access

=item dispatcher

=item logger

=item rabbit_client

=item rabbit_mq

=item template

=item db

=item vce

=back

=cut

sub BUILD{
    my ($self) = @_;
    my $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf', watch => 15);
    my $log    = $logger->get_logger("VCE::Services::Interface");
    $self->_set_logger($log);


    $self->_set_vce( VCE->new() );

    my $dispatcher = GRNOC::WebService::Dispatcher->new();

    $self->_set_template(Template->new());

    $self->_register_interface_functions($dispatcher);

    $self->_set_dispatcher($dispatcher);

    $self->_set_db(VCE::Database::Connection->new('/var/lib/vce/database.sqlite'));

    return $self;
}

sub _register_interface_functions {
    my $self = shift;
    my $d = shift;

    #--- Registering update interface method
    my $method = GRNOC::WebService::Method->new( name => "add_interface",
        description => "Method for adding a interface",
        callback => sub {
            return $self->_add_interface(@_)
        });

    $method->add_input_parameter( required => 1,
        name => 'name',
        pattern => $GRNOC::WebService::Regex::NAME_ID,
        description => "Name of the interface to be added" );

    $method->add_input_parameter( required => 0,
        name => "description",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "interface description");

    $method->add_input_parameter( required => 1,
        name => 'switch_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "Id of the switch connected to the interface" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "ID of the Workgroup" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Workgroup that the user belongs to." );

    eval {
        $d->register_method($method);
    };
    undef $method;

    $method = GRNOC::WebService::Method->new(
        name => "get_interfaces",
        description => "Method for getting an interface",
        callback => sub { return $self->_get_interfaces(@_); }
    );
    $method->add_input_parameter(
        required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::NAME_ID,
        description => "Name of workgroup"
    );
    $method->add_input_parameter(
        required => 0,
        name => 'switch_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "Switch id to filter on"
    );
    $method->add_input_parameter(
        required => 0,
        name => 'workgroup_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "Workgroup id to filter on"
    );
    $method->add_input_parameter(
        required => 0,
        name => 'interface_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "Interface id to filter on"
    );
    eval {
        $d->register_method($method);
    };
    undef $method;


    #--- Registering update interface method
    $method = GRNOC::WebService::Method->new( name => "update_interface",
        description => "Method for updating a interface",
        callback => sub {
            return $self->_update_interface(@_)
        });


    $method->add_input_parameter( required => 1,
        name => 'id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "ID of the interface" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "ID of the Workgroup" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Workgroup that the user belongs to." );


    eval {
        $d->register_method($method);
    };
    undef $method;

    #--- Registering delete interface method
    $method = GRNOC::WebService::Method->new( name => "delete_interface",
        description => "Method for deleting a interface",
        callback => sub {
            return $self->_delete_interface(@_)
        });

    $method->add_input_parameter( required => 1,
        name => 'id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "Name of the interface to be added" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Workgroup that the user belongs to." );

    eval {
        $d->register_method($method);
    };
    undef $method;

}


=head2 handle_request

=cut

sub handle_request{
    my $self = shift;
    $self->dispatcher->handle_request();
}



sub _add_interface {

    warn Dumper("--- in add interface ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $params->{'workgroup'}{'value'};
    if(!$self->vce->access->user_in_workgroup( username => $user,
            workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my ($id, $err) = $self->db->add_interface(
        name            =>  $params->{'name'}{'value'},
        description     =>  $params->{'description'}{'value'},
        switch_id       =>  $params->{'switch_id'}{'value'},
        workgroup_id    =>  $params->{'workgroup_id'}{'value'},
        admin_up        =>  "",
        hardware_type   =>  "",
        link_up         =>  "",
        mac_addr        =>  "",
        mtu             =>  "",
        speed           =>  "",
    );
    warn Dumper("ID: $id");
    if (defined $err) {
        warn Dumper("Error: $err");
        $method_ref->set_error($err);
        return;
    }

    return { results => [ { id => $id } ] }

}


sub _get_interfaces {

    warn Dumper("--- IN GET INTERFACES ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $params->{workgroup}{value};
    my $interface_id = $params->{interface_id}{value};
    my $workgroup_id = $params->{workgroup_id}{value};
    my $switch_id = $params->{switch_id}{value};

    if (!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup)) {
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }
    my $interfaces = [];

    my $wg = $self->db->get_workgroups(name => $workgroup)->[0];
    if (!defined $wg) {
        my $err = "Could not identify specified workgroup.";
        $method_ref->set_error($err);
        return;
    }

    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if ($is_admin) {
        $interfaces = $self->db->get_interfaces(workgroup_id => $workgroup_id, interface_id => $interface_id, switch_id => $switch_id);
    } else {
        $interfaces = $self->db->get_interfaces(workgroup_id => $wg->{id}, interface_id => $interface_id, switch_id => $switch_id);
    }
    if (!defined $interfaces) {
        my $err = "Could not get interfaces from database.";
        warn Dumper("Error: $err");
        $method_ref->set_error($err);
        return;
    }

    return { results => $interfaces };
}


sub _update_interface {
    warn Dumper("--- in update interface ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;
    my $user = $ENV{'REMOTE_USER'};


    my $workgroup = $params->{'workgroup'}{'value'};
    if(!$self->vce->access->user_in_workgroup( username => $user,
            workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my $result = $self->db->update_interface(
        id              => $params->{id}{value},
        workgroup_id    => $params->{workgroup_id}{value},
    );
    warn Dumper("update result: $result");
    if ($result eq 0) {

        $method_ref->set_error("Update failed for interface: $params->{id}{value}");
        return;
    }
    return { results => [ { value => $result } ] }
}

sub _delete_interface {
    warn Dumper("--- in delete interface ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $params->{'workgroup'}{'value'};

    if(!$self->vce->access->user_in_workgroup( username => $user,
            workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my $result = $self->db->delete_interface (
        $params->{id}{value}
    );
    warn Dumper("delete result: $result");

    if ($result eq 0) {

        $method_ref->set_error("Delete failed for interface: $params->{id}{value}");
        return;
    }

    return { results => [ { value => $result } ] }
}
1;
