package VCE::Database::VLAN;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_vlan_acl get_vlan_acls );


sub add_vlan_acl {
    my ( $self, $interface_id, $workgroup_id, $low, $high ) = @_;

    $self->{log}->debug("get_vlan_acls($interface_id, $workgroup_id, $low, $high)");

    my $q = $self->{conn}->prepare(
        "insert into interface_workgroup_vlan_acl
         (interface_id, workgroup_id, low, high)
         values (?, ?, ?, ?)"
    );
    $q->execute($interface_id, $workgroup_id, $low, $high);

    return $self->{conn}->last_insert_id("", "", "interface_workgroup_vlan_acl", "");
}

sub get_vlan_acls {
    my ( $self, $interface_id, $workgroup_id ) = @_;

    $self->{log}->debug("get_vlan_acls($self->{conn}, $interface_id, $workgroup_id)");

    my $q = $self->{conn}->prepare(
        "select * from interface_workgroup_vlan_acl as iwva
         where iwva.workgroup_id=? and iwva.interface_id=?"
    );
    $q->execute($workgroup_id, $interface_id);

    my $acls = $q->fetchall_arrayref({});
    my $result = [];

    foreach my $acl (@$acls) {
        push @$result, { high => $acl->{high}, low  => $acl->{low} };
    }

    return $result;
}

return 1;
