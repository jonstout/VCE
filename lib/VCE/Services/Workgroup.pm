#!/usr/bin/perl

package VCE::Services::Workgroup;

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
    my $log    = $logger->get_logger("VCE::Services::Workgroup");
    $self->_set_logger($log);


    $self->_set_vce( VCE->new() );

    my $dispatcher = GRNOC::WebService::Dispatcher->new();

    $self->_set_template(Template->new());

    $self->_register_workgroup_functions($dispatcher);

    $self->_set_dispatcher($dispatcher);

    $self->_set_db(VCE::Database::Connection->new('/var/lib/vce/database.sqlite'));

    return $self;
}

sub _register_workgroup_functions {
    my $self = shift;
    my $d = shift;

    #--- Registering add_workgroup method
    my $method = GRNOC::WebService::Method->new( name => "add_workgroup",
        description => "Method for adding a workgroup",
        callback => sub {
            return $self->_add_workgroup(@_)
        });

    $method->add_input_parameter( required => 1,
        name => 'name',
        pattern => $GRNOC::WebService::Regex::NAME_ID,
        description => "Name of the workgroup to be added" );

    $method->add_input_parameter( required => 0,
        name => "description",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "workgroup description");

    $method->add_input_parameter( required => 1,
        name => "workgroup",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "check if user belonging to admin workgroup");

    eval {
        $d->register_method($method);
    };
    undef $method;

    #--- Registering add_workgroup method
    $method = GRNOC::WebService::Method->new(
        name => "get_workgroups",
        description => "Method for getting workgroups",
        callback => sub {
            return $self->_get_workgroups(@_)
        });
    $method->add_input_parameter(
        required => 1,
        name => "workgroup",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "check if user belonging to admin workgroup"
    );
    $method->add_input_parameter(
        required => 0,
        name => "workgroup_id",
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "filter result on workgroup_id"
    );
    eval {
        $d->register_method($method);
    };
    undef $method;

    #--- Registering update workgroup method
    $method = GRNOC::WebService::Method->new( name => "update_workgroup",
        description => "Method for updating a workgroup",
        callback => sub {
            return $self->_update_workgroup(@_)
        });


    $method->add_input_parameter( required => 1,
        name => 'id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "ID of the workgroup" );

    $method->add_input_parameter( required => 0,
        name => 'name',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "name of the workgroup that needs to be updated" );

    $method->add_input_parameter( required => 0,
        name => 'description',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "description of the workgroup that needs to be updated" );

    $method->add_input_parameter( required => 1,
        name => "workgroup",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "check if user belonging to admin workgroup");


    eval {
        $d->register_method($method);
    };
    undef $method;

    #--- Registering delete workgroup method
    $method = GRNOC::WebService::Method->new( name => "delete_workgroup",
        description => "Method for deleting a workgroup",
        callback => sub {
            return $self->_delete_workgroup(@_)
        });

    $method->add_input_parameter( required => 1,
        name => 'id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "ID of the workgroup to be deleted" );

    $method->add_input_parameter( required => 1,
        name => "workgroup",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "check if user belonging to admin workgroup");

    eval {
        $d->register_method($method);
    };
    undef $method;

    $method = GRNOC::WebService::Method->new(
        name => "get_workgroup_users",
        description => "Method for removing a user from a workgroup",
        callback => sub { return $self->_get_workgroup_users(@_); }
    );
    $method->add_input_parameter(
        required => 1,
        name => "workgroup",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "user workgroup"
    );
    $method->add_input_parameter(
        required => 1,
        name => 'workgroup_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "(user, workgroup) relationship ID"
    );
    eval {
        $d->register_method($method);
    };
    undef $method;

    $method = GRNOC::WebService::Method->new(
        name => "add_user_to_workgroup",
        description => "Method for adding a user to a workgroup",
        callback => sub { return $self->_add_user_to_workgroup(@_); }
    );
    $method->add_input_parameter(
        required => 1,
        name => "workgroup",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "user workgroup"
    );
    $method->add_input_parameter(
        required => 1,
        name => "role",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Role of user in workgroup."
    );
    $method->add_input_parameter(
        required => 1,
        name => 'user_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "ID of user to add."
    );
    $method->add_input_parameter(
        required => 1,
        name => 'workgroup_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "ID of workgroup to join."
    );
    eval {
        $d->register_method($method);
    };
    undef $method;

    $method = GRNOC::WebService::Method->new(
        name => "remove_user_from_workgroup",
        description => "Method for removing a user from a workgroup",
        callback => sub { return $self->_remove_user_from_workgroup(@_); }
    );
    $method->add_input_parameter(
        required => 1,
        name => "workgroup",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "user workgroup"
    );
    $method->add_input_parameter(
        required => 1,
        name => 'user_workgroup_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "(user, workgroup) relationship ID"
    );
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

# --- add workgroup
sub _add_workgroup {

    warn Dumper("--- in add workgroup ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    # Validations
    my $workgroup = $params->{'workgroup'}{'value'};
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;

    if (!$is_admin) {
        $method_ref->set_error("Workgroup $workgroup is not authorized to add workgroup $params->{name}{value}");
        return;
    }
    if(!$self->vce->access->user_in_workgroup( username => $user,
            workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my ($id, $err) = $self->db->add_workgroup(
        $params->{name}{value},
        $params->{description}{value},
    );
    warn Dumper("ID: $id");
    if (defined $err) {
        warn Dumper("Error: $err");
        $method_ref->set_error($err);
        return;
    }

    return { results => [ { id => $id } ] };
}

# --- get workgroups
sub _get_workgroups {

    warn Dumper("--- in add workgroup ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $params->{workgroup}{value};
    my $workgroup_id = $params->{workgroup_id}{value};

    if (!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup)) {
        $method_ref->set_error("User $user not in specified workgroup $workgroup.");
        return;
    }

    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method_ref->set_error("Workgroup $workgroup is not authorized to get workgroups.");
        return;
    }

    my $workgroups = $self->db->get_workgroups(workgroup_id => $workgroup_id);
    return { results => $workgroups };
}

# --- Update workgroup
sub _update_workgroup {
    warn Dumper("--- in update workgroup ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;
    my $user = $ENV{'REMOTE_USER'};


    # Validations
    my $workgroup = $params->{'workgroup'}{'value'};

    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method_ref->set_error("Workgroup $workgroup is not authorized to update workgroup $params->{id}{value}");
        return;
    }

    if(!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup)){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my $result = $self->db->update_workgroup(
        id              => $params->{id}{value},
        name            => $params->{name}{value},
        description     => $params->{description}{value},
    );

    if ($result eq "0E0") {
        $method_ref->set_error("Update failed for workgroup: $params->{id}{value}");
        return;
    }
    return { results => [ { value => $result } ] };
}

# --- Delete workgroup
sub _delete_workgroup {
    warn Dumper("--- in delete workgroup ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    # Validations
    my $workgroup = $params->{'workgroup'}{'value'};
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method_ref->set_error("Workgroup $workgroup is not authorized to delete workgroup $params->{id}{value}");
        return;
    }
    if(!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup)){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my $result = $self->db->delete_workgroup (
        id => $params->{id}{value}
    );

    if ($result eq "0E0") {
        $method_ref->set_error("Delete failed for workgroup: $params->{id}{value}");
        return;
    }

    return { results => [ { value => $result } ] };
}

sub _add_user_to_workgroup {
    my $self   = shift;
    my $method = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $params->{workgroup}{value};
    my $role = $params->{role}{value};
    my $user_id = $params->{user_id}{value};
    my $workgroup_id = $params->{workgroup_id}{value};

    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method->set_error("Workgroup $workgroup is not authorized to delete workgroup $params->{id}{value}.");
        return;
    }
    if(!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup)){
        $method->set_error("User $user not in workgroup $workgroup.");
        return;
    }

    my ($user_workgroup_id, $err) = $self->db->add_user_to_workgroup($role, $user_id, $workgroup_id);
    if (defined $err) {
        $method->set_error("Couldn't remove user $user from workgroup $workgroup. $err");
        return;
    }

    return { results => [ { id => $user_workgroup_id } ] };
}

sub _remove_user_from_workgroup {
    my $self   = shift;
    my $method = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $params->{workgroup}{value};
    my $user_workgroup_id = $params->{user_workgroup_id}{value};

    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method->set_error("Workgroup $workgroup is not authorized to delete workgroup $params->{id}{value}.");
        return;
    }
    if(!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup)){
        $method->set_error("User $user not in workgroup $workgroup.");
        return;
    }

    my $err = $self->db->remove_user_from_workgroup($params->{user_workgroup_id}{value});
    if (defined $err) {
        $method->set_error("Couldn't remove user $user from workgroup $workgroup. $err");
        return;
    }

    return { results => [ { value => 1 } ] };
}

sub _get_workgroup_users {
    my $self   = shift;
    my $method = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    my $workgroup = $params->{workgroup}{value};
    my $workgroup_id = $params->{workgroup_id}{value};

    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method->set_error("Workgroup $workgroup is not authorized to delete workgroup $params->{id}{value}.");
        return;
    }
    if(!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup)){
        $method->set_error("User $user not in workgroup $workgroup.");
        return;
    }

    my ($workgroups, $err) = $self->db->get_users_by_workgroup_id($workgroup_id);
    if (defined $err) {
        $method->set_error("Couldn't get users of workgroup $workgroup. $err");
        return;
    }

    return { results => $workgroups };
}

1;
