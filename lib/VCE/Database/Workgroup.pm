package VCE::Database::Workgroup;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_workgroup get_workgroup get_workgroups get_workgroup_interfaces );


=head2 add_workgroup


=cut
sub add_workgroup {
    my ( $self, $name, $description ) = @_;

    $self->{log}->debug("add_workgroup($name, $description)");

    my $q = $self->{conn}->prepare(
        "insert into workgroup (name, description) values (?, ?)"
    );
    $q->execute($name, $description);

    return $self->{conn}->last_insert_id("", "", "workgroup", "");
}

=head2 get_workgroup


=cut
sub get_workgroup {
    my $self = shift;
    my %params = @_;

    my $reqs = [];
    my $args = [];
    my $where = '';

    if (defined $params{id}) {
        push @$reqs, 'id=?';
        push @$args, $params{id};
    }
    if (defined $params{name}) {
        push @$reqs, 'name=?';
        push @$args, $params{name};
    }
    $where .= join(' AND ', @$reqs);

    my $q = $self->{conn}->prepare(
        "select * from workgroup WHERE $where",
    );
    $q->execute(@$args);

    my $result = $q->fetchall_arrayref({})->[0];
    return $result;
}

=head2 get_workgroups


=cut
sub get_workgroups {
    my $self = shift;
    my %params = @_;

    $self->{log}->debug("get_workgroups()");

    my $keys = [];
    my $args = [];

    if (defined $params{name}) {
        push @$keys, 'name=?';
        push @$args, $params{name};
    }

    my $values = join(' AND ', @$keys);
    my $where = scalar(@$keys) > 0 ? "WHERE $values" : "";

    my $q = $self->{conn}->prepare(
        "select * from workgroup $where"
    );
    $q->execute(@$args);

    my $result = $q->fetchall_arrayref({});
    return $result;
}

=head2 get_workgroup_interfaces

get_workgroup_interfaces returns a list of all interfaces that
C<workgroup_id> either owns or has access to. Interfaces may appear to
be duplicated if more than one vlan range has been made available to
C<workgroup_id>, although the high and low fields will be different.

=cut
sub get_workgroup_interfaces {
    my ( $self, $workgroup_id ) = @_;

    my $q = $self->{conn}->prepare(
        "select interface.*, switch.name as switch_name, acl.low, acl.high from workgroup
         join interface on workgroup.id=interface.workgroup_id
         join switch on interface.switch_id=switch.id
         join acl on interface.id=acl.interface_id
         where workgroup.id=? OR acl.workgroup_id=?"
    );
    $q->execute($workgroup_id, $workgroup_id);

    my $result = $q->fetchall_arrayref({});
    return $result;
}

return 1;
