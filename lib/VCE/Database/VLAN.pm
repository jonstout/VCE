package VCE::Database::VLAN;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_vlan get_vlans );


sub add_vlan {
    my ( $self ) = @_;

    $self->{log}->debug("add_vlan()");

    my $q = $self->{conn}->prepare(
        "select * from vlan"
    );
    $q->execute();

    return $self->{conn}->last_insert_id("", "", "vlan", "");
}

sub get_vlans {
    my ( $self, $workgroup_id ) = @_;

    $self->{log}->debug("get_vlans($self->{conn}, $workgroup_id)");

    my $q = $self->{conn}->prepare(
        "select * from vlan"
    );
    $q->execute();

    my $vlans = $q->fetchall_arrayref({});
    my $result = [];

    foreach my $vlan (@$vlans) {
        push @$result, $vlan;
    }

    return $result;
}

return 1;
