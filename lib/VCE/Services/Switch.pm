
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
    my $log    = $logger->get_logger("VCE::Services::Switch");
    $self->_set_logger($log);


    $self->_set_vce( VCE->new() );

    my $dispatcher = GRNOC::WebService::Dispatcher->new();
    $self->_set_db(VCE::Database::Connection->new('/var/lib/vce/database.sqlite'));

    $self->_set_template(Template->new());

    $self->_register_switch_functions($dispatcher);

    $self->_set_dispatcher($dispatcher);

    return $self;
}

sub _register_switch_functions {
    my $self = shift;
    my $d = shift;

    #--- Registering add_switch method
    my $method = GRNOC::WebService::Method->new( name => "add_switch",
        description => "Method for adding a switch",
        callback => sub {
            return $self->_add_switch(@_)
        });

    $method->add_input_parameter( required => 1,
        name => 'name',
        pattern => $GRNOC::WebService::Regex::NAME_ID,
        description => "Name of the switch to be added" );


    $method->add_input_parameter( required => 1,
        name => 'ip',
        pattern => $GRNOC::WebService::Regex::IP_ADDRESS,
        description => "IP address of switch" );


    $method->add_input_parameter( required => 0,
        name => "description",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "switch description");


    $method->add_input_parameter( required => 1,
        name => 'ssh',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "ssh port for the switch" );

    $method->add_input_parameter( required => 1,
        name => 'netconf',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "netconf port for the switch" );

    $method->add_input_parameter( required => 1,
        name => "vendor",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Switch vendor");


    $method->add_input_parameter( required => 1,
        name => 'model',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "switch model" );

    $method->add_input_parameter( required => 1,
        name => 'version',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "switch version" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Workgroup that the user belongs to." );

    eval {
        $d->register_method($method);
    };
    undef $method;

    $method = GRNOC::WebService::Method->new(
        name => "get_switches",
        description => "Method for adding a switch",
        callback => sub { return $self->_get_switches(@_); }
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
    eval {
        $d->register_method($method);
    };
    undef $method;

    #--- Registering modify switch method
    $method = GRNOC::WebService::Method->new( name => "modify_switch",
        description => "Method for modifying a switch",
        callback => sub {
            return $self->_modify_switch(@_)
        });


    $method->add_input_parameter( required => 1,
        name => 'id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "id of the switch to be modified " );

    $method->add_input_parameter( required => 1,
        name => 'name',
        pattern => $GRNOC::WebService::Regex::NAME_ID,
        description => "name of the switch to be modified " );


    $method->add_input_parameter( required => 1,
        name => 'ip',
        pattern => $GRNOC::WebService::Regex::IP_ADDRESS,
        description => "IP address of switch" );


    $method->add_input_parameter( required => 0,
        name => "description",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "switch description");


    $method->add_input_parameter( required => 1,
        name => 'ssh',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "ssh port for the switch" );

    $method->add_input_parameter( required => 1,
        name => 'netconf',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "netconf port for the switch" );

    $method->add_input_parameter( required => 1,
        name => "vendor",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Switch vendor");


    $method->add_input_parameter( required => 1,
        name => 'model',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "switch model" );

    $method->add_input_parameter( required => 1,
        name => 'version',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "switch version" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Workgroup that the user belongs to." );

    eval {
        $d->register_method($method);
    };
    undef $method;

    #--- Registering delete switch method
    $method = GRNOC::WebService::Method->new( name => "delete_switch",
        description => "Method for deleting a switch",
        callback => sub {
            return $self->_delete_switch(@_)
        });

    $method->add_input_parameter( required => 1,
        name => 'id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "id of the switch to be deleted" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Workgroup that the user belongs to." );

    eval {
        $d->register_method($method);
    };
    undef $method;


    #--- Registering add_command_to_switch method
    my $method = GRNOC::WebService::Method->new( name => "add_command_to_switch",
        description => "Method for adding command to a switch",
        callback => sub {
            return $self->_add_command_to_switch(@_)
        });

    $method->add_input_parameter( required => 1,
        name => 'command_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "id of the command to be associated with the switch" );

    $method->add_input_parameter( required => 1,
        name => 'switch_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "id of the switch to which command has to be added" );

    $method->add_input_parameter( required => 1,
        name => 'role',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "role" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "workgoup of the user" );

    eval {
        $d->register_method($method);
    };
    undef $method;

    #--- Registering modify_switch_command method
    my $method = GRNOC::WebService::Method->new( name => "modify_switch_command",
        description => "Method for removing command from a switch",
        callback => sub {
            return $self->_modify_switch_command(@_)
        });

    $method->add_input_parameter( required => 1,
        name => 'id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "id of the switch command to be modified" );

    $method->add_input_parameter( required => 1,
        name => 'role',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "role" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "workgoup of the user" );

    eval {
        $d->register_method($method);
    };
    undef $method;

    #--- Registering remove_command_from_switch method
    my $method = GRNOC::WebService::Method->new( name => "remove_command_from_switch",
        description => "Method for removing command from a switch",
        callback => sub {
            return $self->_remove_command_from_switch(@_)
        });

    $method->add_input_parameter( required => 1,
        name => 'id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "id of the switch command to be deleted" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "workgoup of the user" );

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

sub _add_switch {

    warn Dumper("--- in add switch ---");
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
    my ($id, $err) = $self->db->add_switch( $params->{'name'}{'value'},
        $params->{'description'}{'value'},
        $params->{'ip'}{'value'},
        $params->{'ssh'}{'value'},
        $params->{'netconf'}{'value'},
        $params->{'vendor'}{'value'},
        $params->{'model'}{'value'},
        $params->{'version'}{'value'},
    );
    warn Dumper("ID: $id");
    if (defined $err) {
        warn Dumper("Error: $err");
        $method_ref->set_error($err);
        return;
    }

    return { results => [ { id => $id } ] };

}

sub _get_switches {

    warn Dumper("--- in get switches ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $params->{workgroup}{value};
    my $switch_id = $params->{switch_id}{value};

    if (!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup)) {
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }
    my $switches = [];

    my $wg = $self->db->get_workgroups(name => $workgroup)->[0];
    if (!defined $wg) {
        my $err = "Could not identify specified workgroup.";
        $method_ref->set_error($err);
        return;
    }

    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if ($is_admin) {
        $switches = $self->db->get_switches(switch_id => $switch_id);
    } else {
        $switches = $self->db->get_switches(workgroup_id => $wg->{id}, switch_id => $switch_id);
    }
    if (!defined $switches) {
        my $err = "Could not get switches from database.";
        warn Dumper("Error: $err");
        $method_ref->set_error($err);
        return;
    }

    return { results => $switches };
}


sub _modify_switch {
    warn Dumper("--- in modify switche ---");
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

    my $result = $self->db->modify_switch(
        id          => $params->{id}{value},
        name        => $params->{name}{value},
        description => $params->{description}{value},
        ip          => $params->{ip}{value},
        ssh         => $params->{ssh}{value},
        netconf     => $params->{netconf}{value},
        vendor      => $params->{vendor}{value},
        model       => $params->{model}{value},
        version     => $params->{version}{value},
    );
    warn Dumper("modify result: $result");
    if ($result eq "0E0") {

        $result = "Could not find Switch: $params->{name}{value}, ID: $params->{id}{value}";
        $method_ref->set_error($result);
        return;
    }
    return { results => [ { value => $result } ] };
}

sub _delete_switch {
    warn Dumper("IN DELETE SWITCH");
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

    my $result = $self->db->delete_switch (id => $params->{id}{value});
    warn Dumper("DELETE RESULT: $result");

    if ($result eq "0E0") {
        $result = "Could not find Switch: $params->{id}{value}";
        $method_ref->set_error($result);
        return;
    }

    return { results => [ { value => $result } ] };
}

sub _add_command_to_switch  {

    warn Dumper("--- IN ADD SWITCH ---");
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
    my ($id, $err) = $self->db->add_switch( $params->{'name'}{'value'},
        $params->{'description'}{'value'},
        $params->{'ip'}{'value'},
        $params->{'ssh'}{'value'},
        $params->{'netconf'}{'value'},
        $params->{'vendor'}{'value'},
        $params->{'model'}{'value'},
        $params->{'version'}{'value'},
    );
    warn Dumper("ID: $id");
    if (defined $err) {
        warn Dumper("Error: $err");
        $method_ref->set_error($err);
        return;
    }

    return { results => [ { id => $id } ] };

}

1;
