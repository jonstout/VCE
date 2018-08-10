package VCE::Database::VLAN;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_vlan get_vlan get_vlans delete_vlan );


=head2 add_vlan

=cut
sub add_vlan {
    my $self = shift;
    my %params = @_;

    return if (!defined $params{created_by});
    return if (!defined $params{number});
    return if (!defined $params{switch_id});
    return if (!defined $params{workgroup_id});

    $self->{log}->debug("add_vlan($params{name}, $params{number}, $params{description}, $params{created_by}, $params{created_on}, $params{switch_id}, $params{workgroup_id})");

    my $q = $self->{conn}->prepare(
        "insert into vlan (
           name, number, description, created_by, switch_id, workgroup_id, created_on
         ) values (?, ?, ?, ?, ?, ?, ?)"
    );
    eval {
        $q->execute(
            $params{name},
            $params{number},
            $params{description},
            $params{created_by},
            $params{switch_id},
            $params{workgroup_id},
            $params{created_on} || time()
        );
    };
    if ($@) {
        $self->{log}->error("$@");
        return;
    }
    return $self->{conn}->last_insert_id("", "", "vlan", "");
}

=head2 get_vlan

=cut
sub get_vlan {
    my ( $self, $vlan_id ) = @_;

    $self->{log}->debug("get_vlan($vlan_id)");

    my $q = $self->{conn}->prepare(
        "select * from vlan
         where id=?"
    );
    $q->execute($vlan_id);

    my $result = $q->fetchall_arrayref({});

    return $result->[0];
}

=head2 get_vlans
=cut
sub get_vlans {
    my $self = shift;
    my %params = @_;

    $self->{log}->debug("get_vlans()");

    my $keys = [];
    my $args = [];

    if (defined $params{switch_id}) {
        push @$keys, 'vlan.switch_id=?';
        push @$args, $params{switch_id};
    }
    if (defined $params{workgroup_id}) {
        # does not concern itself with who has access to a vlan rather
        # only who owns the vlan

        #push @$keys, '(vlan.workgroup_id=? OR interface.workgroup_id=?)';
        #push @$args, $params{workgroup_id};
        push @$keys, '(vlan.workgroup_id=?)';
        push @$args, $params{workgroup_id};
    }

    my $values = join(' AND ', @$keys);
    my $where = scalar(@$keys) > 0 ? "WHERE $values" : "";

    my $q = $self->{conn}->prepare(
        "select * from vlan
         $where
         group by vlan.id
         order by vlan.number asc"
    );
    $q->execute(@$args);

    my $result = $q->fetchall_arrayref({});
    return $result;
}

=head2 delete_vlan
=cut
sub delete_vlan {
    my ( $self, $vlan_id ) = @_;

    $self->{log}->debug("Calling delete_vlan");

    if (!defined $vlan_id) {
        $self->{log}->error("No vlan_id specified");
        return;
    }

    eval {
        my $q = $self->{conn}->prepare(
            "delete from vlan where id=?"
        );
        $q->execute($vlan_id);
    };
    if ($@) {
        $self->{log}->error("$@");
        return 0;
    }
    return 1;
}

return 1;
