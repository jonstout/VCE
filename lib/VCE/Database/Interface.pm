package VCE::Database::Interface;

use strict;
use warnings;
use Data::Dumper;
use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_interface get_interface get_interfaces );


sub add_interface {
    my ( $self, $admin_up, $name, $description, $link_up, $owner_id, $switch_id ) = @_;

    $self->{log}->debug("add_switch($admin_up, $name, $description, $link_up, $owner_id, $switch_id)");

    my $q = $self->{conn}->prepare(
        "insert into interface
         (admin_up, name, description, link_up, owner_id, switch_id)
         values (?, ?, ?, ?, ?, ?)"
    );
    $q->execute($admin_up, $name, $description, $link_up, $owner_id, $switch_id);

    return $self->{conn}->last_insert_id("", "", "interface", "");
}

sub get_interface {
    my ( $self, $workgroup_id, $interface_id ) = @_;

    $self->{log}->debug("get_interface($self->{conn}, $interface_id)");

    my $q = $self->{conn}->prepare(
        "select * from interface as i
         where i.id=?"
    );
    $q->execute($interface_id);

    my $result = $q->fetchall_arrayref({});
    my $interface = $result->[0];

#    my $vlans = get_vlan_acls($workgroup_id, $interface_id);
    $interface->{vlans} = [];

    return $interface;
}

sub get_interfaces {
    my ( $self ) = @_;

    $self->{log}->debug("get_interfaces( )");

    my $q = $self->{conn}->prepare(
        "select * from interface"
    );
    $q->execute();

    my $result = $q->fetchall_arrayref({});
    return $result;
}

return 1;
