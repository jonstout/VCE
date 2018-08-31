package VCE::Database::User;

use strict;
use warnings;
use Data::Dumper;
use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( delete_user modify_user add_user add_user_to_workgroup get_user get_users get_user_by_name get_users_by_workgroup_id );


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

=head2 modify_user
=cut

sub modify_user{
    my $self = shift;
    my %params = @_;
    return if (!defined $params{user_id});

    $self->{log}->debug("modify_user($params{user_id}, ...)");

    my $keys = [];
    my $args = [];

    if (defined $params{email}) {
        push @$keys, 'email=?';
        push @$args, $params{email};
    }
    if (defined $params{fullname}) {
        push @$keys, 'fullname=?';
        push @$args, $params{fullname};
    }

    my $values = join(', ', @$keys);
    push @$args, $params{user_id};

    my $result;
    eval{
        my $q = $self->{conn}->prepare(
            "UPDATE user SET $values where id=?"
        );
        $result = $q->execute(@$args);
    };
    if($@){
        $self->{log}->error("$@");
        return 0;
    }
    return $result;
}

=head2 get_users
=cut
sub get_users {
    my $self = shift;
    my %params = @_;

    $self->{log}->debug("get_users()");

    my $keys = [];
    my $args = [];

    if (defined $params{user_id}) {
        push @$keys, 'user.id=?';
        push @$args, $params{user_id};
    }
    if (defined $params{fullname}) {
        push @$keys, 'user.fullname like ?';
        push @$args, '%' . $params{type} . '%';
    }
    if(defined($params{email})){
        push @$keys, 'user.email=?';
        push @$args, $params{email};
    }
    if(defined($params{username})){
        push @$keys, 'user.username like ?';
        push @$args, '%' . $params{username} . '%';
    }

    my $values = join(' AND ', @$keys);
    my $where = scalar(@$keys) > 0 ? "WHERE $values" : "";

    my $q;
    eval{
        $q = $self->{conn}->prepare(
            "select * from user $where order by username asc"
        );
        $q->execute(@$args);
    };
    if($@){
        $self->{log}->error("Error executing SQL: " . Dumper($@));
        return;
    }

    my $result = $q->fetchall_arrayref({});
    return $result;
}

=head2 delete_user
=cut
sub delete_user{
    my $self = shift;
    my $user_id = shift;
    
    my $q;
    my $res;
    eval{
	$q = $self->{conn}->prepare("delete from user where id = ?");
	$res = $q->execute($user_id);
    };
    if($@){
	$self->{log}->error("Error executing SQL: " . Dumper($@));
	return;
    }

    return $res;
}

=head2 get_users_by_workgroup_id
=cut
sub get_users_by_workgroup_id {
    my ( $self, $workgroup_id ) = @_;

    $self->{log}->debug("get_users_by_workgroup_id($workgroup_id)");


    my $w;
    eval{
	$w = $self->{conn}->prepare(
	    "select user.*, user_workgroup.id as user_workgroup_id, user_workgroup.role, workgroup.id as workgroup_id, workgroup.name as workgroup_name
         from user
         join user_workgroup on user_workgroup.user_id=user.id
         join workgroup on workgroup.id=user_workgroup.workgroup_id
         where workgroup.id=?"
	    );
    $w->execute($workgroup_id);
    };
    if($@){
	$self->{log}->error("Error executing SQL: " . Dumper($@));
	return;
    }
    return $w->fetchall_arrayref({});
}

1;
