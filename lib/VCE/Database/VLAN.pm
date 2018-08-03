package VCE::Database::VLAN;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_vlan get_vlans );


sub add_vlan {
    my $self = shift;
    my %params = @_;

    return if (!defined $params{created_by});
    return if (!defined $params{description});
    return if (!defined $params{name});
    return if (!defined $params{number});
    return if (!defined $params{workgroup_id});

    $self->{log}->debug("add_vlan($params{name}, $params{number}, $params{description}, $params{created_by}, $params{created_on}, $params{workgroup_id})");

    my $q = $self->{conn}->prepare(
        "insert into vlan (
           name, number, description, created_by, workgroup_id, created_on
         ) values (?, ?, ?, ?, ?, ?)"
    );
    $q->execute(
        $params{name},
        $params{number},
        $params{description},
        $params{created_by},
        $params{workgroup_id},
        $params{created_on} || time()
    );

    return $self->{conn}->last_insert_id("", "", "vlan", "");
}

sub get_vlans {
    my ( $self ) = @_;

    $self->{log}->debug("get_vlans()");

    my $q = $self->{conn}->prepare(
        "select * from vlan"
    );
    $q->execute();

    my $result = $q->fetchall_arrayref({});
    return $result;
}

return 1;
