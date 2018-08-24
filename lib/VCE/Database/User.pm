package VCE::Database::User;

use strict;
use warnings;
use Data::Dumper;
use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_user add_user_to_workgroup get_user get_users get_user_by_name get_users_by_workgroup_id );


=head2 add_user
=cut
sub add_user {
    my ( $self, $username, $email, $fullname ) = @_;

    $self->{log}->debug("add_user($username, $email, $fullname)");

    my $q = $self->{conn}->prepare(
        "insert into user (username, email, fullname) values (?, ?, ?)"
    );
    $q->execute($username, $email, $fullname);

    return $self->{conn}->last_insert_id("", "", "user", "");
}

=head2 add_user_to_workgroup
=cut
sub add_user_to_workgroup {
    my ( $self, $user_id, $workgroup_id, $role ) = @_;

    $role = $role || 'admin';

    $self->{log}->debug("add_user_to_workgroup($user_id, $workgroup_id, $role)");

    my $q = $self->{conn}->prepare(
        "insert into user_workgroup (user_id, workgroup_id, role) values (?, ?, ?)"
    );
    $q->execute($user_id, $workgroup_id, $role);

    return $self->{conn}->last_insert_id("", "", "user_workgroup", "");
}

=head2 get_user
=cut
sub get_user {
    my ( $self, $user_id ) = @_;

    $self->{log}->debug("get_user($user_id)");

    my $q = $self->{conn}->prepare(
        "select * from user where id=?"
    );
    $q->execute($user_id);

    my $user = $q->fetchall_arrayref({})->[0];

    my $w = $self->{conn}->prepare(
        "select w.id, w.name, uw.role, w.description
         from user_workgroup as uw
         join workgroup as w on w.id=uw.workgroup_id
         where uw.user_id=?"
    );
    $w->execute($user_id);

    my $wg = $w->fetchall_arrayref({});
    $user->{workgroups} = $wg;

    return $user;
}

=head2 get_user_by_name
=cut
sub get_user_by_name {
    my ( $self, $username ) = @_;

    $self->{log}->debug("get_user_by_name($username)");

    my $q = $self->{conn}->prepare(
        "select * from user where username=?"
    );
    $q->execute($username);

    my $user = $q->fetchall_arrayref({})->[0];
    if (!defined $user) {
        return;
    }

    my $w = $self->{conn}->prepare(
        "select w.id, w.name, uw.role, w.description
         from user_workgroup as uw
         join workgroup as w on w.id=uw.workgroup_id
         where uw.user_id=?"
    );
    $w->execute($user->{id});

    my $wg = $w->fetchall_arrayref({});
    $user->{workgroups} = $wg;

    return $user;
}

=head2 get_users
=cut
sub get_users {
    my ( $self ) = @_;

    $self->{log}->debug("get_users()");

    my $q = $self->{conn}->prepare(
        "select * from user"
    );
    $q->execute();

    my $result = $q->fetchall_arrayref({});
    return $result;
}

=head2 get_users_by_workgroup_id
=cut
sub get_users_by_workgroup_id {
    my ( $self, $workgroup_id ) = @_;

    $self->{log}->debug("get_users_by_workgroup_id($workgroup_id)");

    my $w = $self->{conn}->prepare(
        "select user.username from user
         join user_workgroup on user_workgroup.user_id=user.id
         join workgroup on workgroup.id=user_workgroup.workgroup_id
         where workgroup.id=?"
    );
    $w->execute($workgroup_id);

    return $w->fetchall_arrayref({});
}

return 1;
