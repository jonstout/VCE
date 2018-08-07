package VCE::Database::VLAN;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_vlan get_vlans delete_vlan );


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

sub get_vlans {
    my $self = shift;
    my %params = @_;

    $self->{log}->debug("get_vlans()");

    my $q = undef;
    if (defined $params{switch_id}) {
        $q = $self->{conn}->prepare(
            "select * from vlan where switch_id=?"
        );
        $q->execute($params{switch_id});
    } else {
        $q = $self->{conn}->prepare(
            "select * from vlan"
        );
        $q->execute();
    }

    my $result = $q->fetchall_arrayref({});
    return $result;
}

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
