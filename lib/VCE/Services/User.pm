#!/usr/bin/perl
package VCE::Services::User;

use strict;
use warnings;

use Moo;
use GRNOC::Log;
use GRNOC::WebService::Dispatcher;
use GRNOC::WebService::Method;
use GRNOC::WebService::Regex;

use VCE::Access;
use VCE::Database::Connection;

has vce => (is => 'rwp');
has db => (is => 'rwp');
has logger => (is => 'rwp');
has dispatcher => (is => 'rwp');

=head2 BUILD

=over 4

=item access

=item db

=item dispatcher

=item logger

=item vce

=back

=cut

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf', watch => 15);
    my $log    = $logger->get_logger("VCE::Services::User");
    $self->_set_logger($log);

    $self->_set_vce( VCE->new() );

    my $dispatcher = GRNOC::WebService::Dispatcher->new();
    $self->_set_db(VCE::Database::Connection->new('/var/lib/vce/database.sqlite'));

    $self->_register_methods($dispatcher);

    $self->_set_dispatcher($dispatcher);

    return $self;
}

sub _register_methods{
    my $self = shift;
    my $dispatcher = shift;

    my $method = GRNOC::WebService::Method->new(
        name => 'get_users',
        description => 'get a list of users',
        callback => sub { return $self->get_users(@_); }
	);
    $method->add_input_parameter(
        required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::NAME_ID,
        description => "name of current users workgroup"
	);
    $method->add_input_parameter(
        required => 0,
        name => 'username',
        pattern => $GRNOC::WebService::Regex::NAME_ID,
        description => "username of the user"
    );
    $method->add_input_parameter(
        required => 0,
        name => 'email',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "email of the user"
    );
    $method->add_input_parameter(
        required => 0,
        name => 'fullname',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "fullname of the user"
    );
    $method->add_input_parameter(
        required => 0,
        name => 'user_id',
        pattern => $GRNOC::WebService::Regex::NUMBER_ID,
        description => "user_id of the user to find"
    );
    $dispatcher->register_method($method);

    $method = GRNOC::WebService::Method->new(
        name => 'get_current',
        description => 'get user details',
        callback => sub { return $self->get_current(@_); }
	);
    $dispatcher->register_method($method);

    $method = GRNOC::WebService::Method->new(
        name => 'modify_user',
        description => 'Modifies and existing user',
        callback => sub { return $self->modify_user(@_); }
	);
    $method->add_input_parameter(
        required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::NAME_ID,
        description => "name of current users workgroup"
	);
    $method->add_input_parameter(
        required => 0,
        name => 'email',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Email address of the new user"
    );
    $method->add_input_parameter(
        required => 0,
        name => 'fullname',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Full Name of the new user"
    );
    $method->add_input_parameter(
        required => 1,
        name => 'user_id',
        pattern => $GRNOC::WebService::Regex::NUMBER_ID,
        description => "User ID of the user to modify"
    );
    $dispatcher->register_method($method);

    $method = GRNOC::WebService::Method->new(
        name => 'delete_user',
        description => 'deletes and existing user',
        callback => sub { return $self->delete_user(@_); }
    );
    $method->add_input_parameter(
        required => 1,
        name => 'workgroup',
        pattern => $GRNOC::WebService::Regex::NAME_ID,
        description => "name of current users workgroup"
	);
    $method->add_input_parameter(
        required => 1,
        name => 'user_id',
        pattern => $GRNOC::WebService::Regex::NUMBER_ID,
        description => "the id of the user to delete"
    );
    $dispatcher->register_method($method);
}

=head2 get_current

=cut
sub get_current {
    my $self   = shift;
    my $method = shift;
    my $params = shift;

    my $details = $self->db->get_user_by_name($ENV{REMOTE_USER});
    if (defined $details) {
        return { results => $details };
    }

    my $id = $self->db->add_user($ENV{REMOTE_USER}, '', '');
    if (!defined $id) {
        $method->set_error("User '$ENV{REMOTE_USER}' could not be created. Please try again later.");
        return;
    }

    $details = $self->db->get_user_by_name($ENV{REMOTE_USER});
    if (!defined $details) {
        $method->set_error("Something went wrong while creating '$ENV{REMOTE_USER}'. Please try again later.");
        return;
    }

    return { results => $details };
}

=head2 get_users

=cut
sub get_users{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};
    my $workgroup = $p_ref->{'workgroup'}{'value'};

    if (!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup )) {
        $m_ref->set_error("User $user not in workgroup $workgroup.");
        return;
    }
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $m_ref->set_error("Workgroup $workgroup is not authorized to get users.");
        return;
    }

    my %args;

    foreach my $key (keys (%{$p_ref})){
	$args{$key} = $p_ref->{$key}{'value'};
    }

    my $res = $self->db->get_users( %args );
    return {results => $res};
}

=head2 modify_user

=cut
sub modify_user{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user_id = $p_ref->{'user_id'}{'value'};
    my $username = $p_ref->{'username'}{'value'};
    my $fullname = $p_ref->{'fullname'}{'value'};
    my $email = $p_ref->{'email'}{'value'};

    my $user = $ENV{'REMOTE_USER'};
    my $workgroup = $p_ref->{'workgroup'}{'value'};

    if (!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup )) {
        $m_ref->set_error("User $user not in workgroup $workgroup.");
        return;
    }
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $m_ref->set_error("Workgroup $workgroup is not authorized to modify users.");
        return;
    }

    my $res = $self->db->modify_user(
        user_id => $user_id,
        username => $username,
        fullname => $fullname,
        email => $email
    );
    if ($res eq "0E0") {
        $m_ref->set_error("Update failed for user: $user_id");
        return;
    }
    return {results => [$res]};
}

=head2 delete_user

=cut
sub delete_user{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user = $ENV{'REMOTE_USER'};
    my $workgroup = $p_ref->{'workgroup'}{'value'};

    if (!$self->vce->access->user_in_workgroup(username => $user, workgroup => $workgroup )) {
        $m_ref->set_error("User $user not in workgroup $workgroup.");
        return;
    }
    my $is_admin = $self->vce->access->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if (!$is_admin) {
        $m_ref->set_error("Workgroup $workgroup is not authorized to delete users.");
        return;
    }

    my $user_id = $p_ref->{'user_id'}{'value'};

    my $res = $self->db->delete_user($user_id);
    if ($res eq "0E0") {
        $m_ref->set_error("Delete failed for user: $user_id");
        return;
    }
    return {results => [$res]};
}


=head2 handle_request

=cut
sub handle_request{
    my $self = shift;

    $self->dispatcher->handle_request();
}

1;
