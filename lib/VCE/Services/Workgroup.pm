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

    my $workgroup = $params->{'workgroup'}{'value'};
    if(!$self->vce->access->user_in_workgroup( username => $user,
            workgroup => $workgroup )){
        $method_ref->set_error("User $user not in specified workgroup $workgroup");
        return;
    }

    my ($id, $err) = $self->db->add_workgroup(
        $params->{'name'}{'value'},
        $params->{'description'}{'value'},
    );
    warn Dumper("ID: $id");
    if (defined $err) {
        warn Dumper("Error: $err");
        $method_ref->set_error($err);
        return;
    }

    return { results => [ { id => $id } ] }

}


# --- Update workgroup
sub _update_workgroup {
    warn Dumper("--- in update workgroup ---");
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

    my $result = $self->db->update_workgroup(
        id              => $params->{id}{value},
        name            => $params->{name}{value},
        description     => $params->{description}{value},
    );
    warn Dumper("update result: $result");
    if ($result eq "0E0") {

        $method_ref->set_error("Update failed for workgroup: $params->{id}{value}");
        return;
    }
    return { results => [ { value => $result } ] }
}

# --- Delete workgroup
sub _delete_workgroup {
    warn Dumper("--- in delete workgroup ---");
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

    my $result = $self->db->delete_workgroup (
        id => $params->{id}{value}
    );
    warn Dumper("delete result: $result");

    if ($result eq "0E0") {

        $method_ref->set_error("Delete failed for workgroup: $params->{id}{value}");
        return;
    }

    return { results => [ { value => $result } ] }
}
1;
