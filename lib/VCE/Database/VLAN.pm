package VCE::Database::VLAN;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( get_vlan_acls );


sub get_vlan_acls {
    my ( $self, $workgroup_id, $interface_id ) = @_;

    $self->{log}->debug("get_vlan_acls($self->{conn}, $workgroup_id, $interface_id)");

    my $q = $self->{conn}->prepare(
        "select * from interface_workgroup_vlan_acl as iwva
         where iwva.workgroup_id=? and iwva.interface_id=?"
    );
    $q->execute($workgroup_id, $interface_id);

    my $acls = $q->fetchall_arrayref({});
    my $result = [];

    foreach my $acl (@$acls) {
        push @$result, {
            high => $acl->{high},
            low  => $acl->{low}
        };
    }

    return $result;
}

return 1;
