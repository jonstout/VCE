#!/usr/bin/perl

package VCE::Services::ACL;

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
    my $log    = $logger->get_logger("VCE::Services::ACL");
    $self->_set_logger($log);


    $self->_set_vce( VCE->new() );

    my $dispatcher = GRNOC::WebService::Dispatcher->new();

    $self->_set_template(Template->new());

    $self->_register_acl_functions($dispatcher);

    $self->_set_dispatcher($dispatcher);

    $self->_set_db(VCE::Database::Connection->new('/var/lib/vce/database.sqlite'));

    return $self;
}

sub _register_acl_functions {
    my $self = shift;
    my $d = shift;

    #--- Registering modify acl method
    my $method = GRNOC::WebService::Method->new( name => "add_acl",
        description => "Method for adding an acl",
        callback => sub {
            return $self->_add_acl(@_)
        });

    $method->add_input_parameter( required => 1,
        name => 'interface_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "Interface id of the acl to be added" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup_id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "Workgroup id of the acl to be added" );

    $method->add_input_parameter( required => 1,
        name => 'low',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "low value" );

    $method->add_input_parameter( required => 1,
        name => 'high',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "high value" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Workgroup that the user belongs to." );

    eval {
        $d->register_method($method);
    };
    undef $method;

    #--- Registering modify acl method
    $method = GRNOC::WebService::Method->new( name => "modify_acl",
        description => "Method for modifying an acl",
        callback => sub {
            return $self->_modify_acl(@_)
        });


    $method->add_input_parameter( required => 1,
        name => 'id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "id of the acl to be modified" );

    $method->add_input_parameter( required => 1,
        name => 'low',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "low value" );

    $method->add_input_parameter( required => 1,
        name => 'high',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "high value" );

    $method->add_input_parameter( required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Workgroup that the user belongs to." );

    eval {
        $d->register_method($method);
    };
    undef $method;

    #--- Registering delete acl method
    $method = GRNOC::WebService::Method->new( name => "delete_acl",
        description => "Method for deleting an acl",
        callback => sub {
            return $self->_delete_acl(@_)
        });

    $method->add_input_parameter( required => 1,
        name => 'id',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "id of the acl to be deleted" );

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



sub _add_acl {

    warn Dumper("--- in add acl ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};

    # Validation
    my $workgroup = $params->{workgroup}{value};
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method_ref->set_error("Workgroup $workgroup is not authorized to add ACL.");
        return;
    }
    if(!$self->vce->access->user_in_workgroup( username => $user,
            workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }


    my ($id, $err) = $self->db->add_acl(
        $params->{workgroup_id}{value},
        $params->{interface_id}{value},
        $params->{low}{value},
        $params->{high}{value},
    );
    warn Dumper("ID: $id");
    if (defined $err) {
        warn Dumper("Error: $err");
        $method_ref->set_error($err);
        return;
    }

    return { results => [ { id => $id } ] }

}


sub _modify_acl {
    warn Dumper("--- in modify acl ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;
    my $user = $ENV{'REMOTE_USER'};


    # Validation
    my $workgroup = $params->{workgroup}{value};
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method_ref->set_error("Workgroup $workgroup is not authorized to delete ACL.");
        return;
    }

    if(!$self->vce->access->user_in_workgroup( username => $user,
            workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my $result = $self->db->modify_acl(
        id          => $params->{id}{value},
        low         => $params->{low}{value},
        high        => $params->{high}{value},
    );
    warn Dumper("modify result: $result");
    if ($result eq 0) {

        $result = "Update ACL failed for ID: $params->{id}{value}";
        $method_ref->set_error($result);
        return;
    }

    # 0E0 is success: 0 rows affected
    if ($result eq "0E0") {
        $result = 0;
    }
    return { results => [ { value => $result } ] }
}

sub _delete_acl {
    warn Dumper("--- in delete acl ---");
    my $self = shift;
    my $method_ref = shift;
    my $params = shift;

    my $user = $ENV{'REMOTE_USER'};


    # Validation
    my $workgroup = $params->{workgroup}{value};
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $method_ref->set_error("Workgroup $workgroup is not authorized to delete ACL.");
        return;
    }

    if(!$self->vce->access->user_in_workgroup( username => $user,
            workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my $result = $self->db->delete_acl (
        $params->{id}{value}
    );
    warn Dumper("delete result: $result");

    if ($result eq 0) {

        $result = "Delete ACL failed for ID: $params->{id}{value}";
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
