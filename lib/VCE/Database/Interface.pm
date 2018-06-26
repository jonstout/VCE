package Database::Interface;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( get_switch );


sub get_interface {
    my ( $self, $workgroup_id, $interface_id ) = @_;

    $self->{log}->debug("get_interface($self->{conn}, $interface_id)");

    my $q = $self->{conn}->prepare(
        "select * from interface as i
         where i.interface_id=?"
    );
    $q->execute($interface_id);

    my $result = $q->fetchall_arrayref({});
    my $interface = $result->[0];

    my $vlans = get_vlan_acls($workgroup_id, $interface_id);
    $interface->{vlans} = $vlans;

    return $interface;
}

return 1;
