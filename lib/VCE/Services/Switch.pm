
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
has rabbit_mq => (is => 'rwp');
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
    $method = GRNOC::WebService::Method->new( name => "add_command_to_switch",
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


    $method = GRNOC::WebService::Method->new(
        name => "get_switch_commands",
        description => "Method for adding command to a switch",
        callback => sub {
            return $self->_get_switch_commands(@_)
        }
    );
    $method->add_input_parameter(
        required => 1,
        name => 'switch_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "id of the switch commands to return"
    );
    $method->add_input_parameter( required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "workgoup of the requesting user"
    );
    eval {
        $d->register_method($method);
    };
    undef $method;

    #--- Registering modify_switch_command method
    $method = GRNOC::WebService::Method->new( name => "modify_switch_command",
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
    $method = GRNOC::WebService::Method->new( name => "remove_command_from_switch",
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

#--- Method to add switches
sub _add_switch {

    warn Dumper("--- in add switch ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    # Validation
    my $workgroup = $params->{workgroup}{value};
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method_ref->set_error("Workgroup $workgroup is not authorized to add switch.");
        return;
    }

    if(!$self->vce->access->user_in_workgroup( username => $user,
					       workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my ($id, $err) = $self->db->add_switch( $params->{name}{value},
        $params->{description}{value},
        $params->{ip}{value},
        $params->{ssh}{value},
        $params->{netconf}{value},
        $params->{vendor}{value},
        $params->{model}{value},
        $params->{version}{value},
    );
    warn Dumper("add switch result id: $id");
    if (defined $err) {
        warn Dumper("Error: $err");
        $method_ref->set_error($err);
        return;
    }



    #build rabbitmq client
    my $client = GRNOC::RabbitMQ::Client->new(
        user     => $self->rabbit_mq->{'user'},
        pass     => $self->rabbit_mq->{'pass'},
        host     => $self->rabbit_mq->{'host'},
        timeout  => 30,
        port     => $self->rabbit_mq->{'port'},
        exchange => 'VCE',
        topic    => 'VCE'
	);    

    my $res = $client->add_switch(switch_id => $id);
    
    my $status = 1;
    if(!defined($res) || !defined($res->{'success'})){
	$method_ref->set_error("Timeout occured talking to VCE process, please check the logs or check with the system administrator. " . $res->{'error'});
	$status = 0;
    }else{
	if($res->{'success'} == 0){
	    $method_ref->set_error("Error attempting to create switch process, was switch added to the database?" . $res->{'error'});
	    $status = 0;
	}
    }

    return { results => [ { id => $id, status => $status } ] };

}


#--- Method to get switches
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


#--- Method to modify switches
sub _modify_switch {
    warn Dumper("--- in modify switch ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;
    my $user = $ENV{'REMOTE_USER'};

    # Validation
    my $workgroup = $params->{workgroup}{value};
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method_ref->set_error("Workgroup $workgroup is not authorized to modify switch.");
        return;
    }

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
    warn Dumper("modify switch result: $result");
    if ($result eq 0) {
        $result = "Update Switch failed for ID: $params->{id}{value}";
        $method_ref->set_error($result);
        return;
    }

    # 0E0 is success: 0 rows affected
    if ($result eq "0E0") {
        $result = 0;
    }
    return { results => [ { value => $result } ] };
}


#--- Method to modify the switch
sub _delete_switch {
    warn Dumper("--- in delete switch ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    # Validation
    my $workgroup = $params->{workgroup}{value};
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method_ref->set_error("Workgroup $workgroup is not authorized to delete switch.");
        return;
    }

    if(!$self->vce->access->user_in_workgroup( username => $user,
            workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my $switch = $self->db->get_switch( $params->{id}{value} );

    my $result = $self->db->delete_switch (
        $params->{id}{value}
    );
    warn Dumper("delete switch result: $result");

    if ($result eq 0) {
        $result = "Delete Switch failed for ID: $params->{id}{value}";
        $method_ref->set_error($result);
        return;
    }

    # 0E0 is success: 0 rows affected
    if ($result eq "0E0") {
        $result = 0;
    }


    #build rabbitmq client
    my $client = GRNOC::RabbitMQ::Client->new(
        user     => $self->rabbit_mq->{'user'},
        pass     => $self->rabbit_mq->{'pass'},
        host     => $self->rabbit_mq->{'host'},
        timeout  => 30,
        port     => $self->rabbit_mq->{'port'},
        exchange => 'VCE',
        topic    => "VCE.Switch." . $switch->{'name'}
        ); 

    return { results => [ { value => $result } ] };
}


#--- Method to associate a command with a switch
sub _add_command_to_switch  {

    warn Dumper("--- in add command to switch ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    # Validation
    my $workgroup = $params->{workgroup}{value};
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method_ref->set_error("Workgroup $workgroup is not authorized to add command to a switch.");
        return;
    }

    if(!$self->vce->access->user_in_workgroup( username => $user,
            workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my ($id, $err) = $self->db->add_command_to_switch(
        $params->{command_id}{value},
        $params->{switch_id}{value},
        $params->{role}{value}
    );
    warn Dumper("add switch_command result: $id");
    if (defined $err) {
        warn Dumper("Error: $err");
        $method_ref->set_error($err);
        return;
    }

    return { results => [ { id => $id } ] };
}

#--- Method to get commands associated with switch
sub _get_switch_commands  {
    my $self = shift;
    my $method = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};
    my $workgroup = $params->{workgroup}{value};
    my $switch_id = $params->{switch_id}{value};

    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method->set_error("Workgroup $workgroup is not authorized to get switch command associations.");
        return;
    }
    if (!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup)) {
        $method->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my $commands = $self->db->get_assigned_commands(switch_id => $switch_id);
    return { results => $commands };
}

#--- Method to remove a command from a switch
sub _remove_command_from_switch {

    warn Dumper("--- in remove command from switch ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    # Validation
    my $workgroup = $params->{workgroup}{value};
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method_ref->set_error("Workgroup $workgroup is not authorized to remove command from a switch.");
        return;
    }

    if(!$self->vce->access->user_in_workgroup( username => $user,
            workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my $result = $self->db->remove_command_from_switch (
        $params->{id}{value}
    );
    warn Dumper("delete switch_command result: $result");

    if ($result eq 0) {

        $result = "Delete command from switch failed for ID: $params->{id}{value}";
        $method_ref->set_error($result);
        return;
    }

    # 0E0 is success: 0 rows affected
    if ($result eq "0E0") {
        $result = 0;
    }

    return { results => [ { value => $result } ] }
}

#--- Method to modify command's role on the switch
sub _modify_switch_command {

    warn Dumper("--- in modify switch command ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    # Validation
    my $workgroup = $params->{workgroup}{value};
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method_ref->set_error("Workgroup $workgroup is not authorized to remove command from a switch.");
        return;
    }

    if(!$self->vce->access->user_in_workgroup( username => $user,
            workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my $result = $self->db->modify_switch_command (
        $params->{id}{value},
        $params->{role}{value}
    );
    warn Dumper("modify switch_command result: $result");

    if ($result eq 0) {

        $result = "Modify switch_command failed for ID: $params->{id}{value}";
        $method_ref->set_error($result);
        return;
    }

    # 0E0 is success: 0 rows affected
    if ($result eq "0E0") {
        $result = 0;
    }

    return { results => [ { value => $result } ] }
}

1;
