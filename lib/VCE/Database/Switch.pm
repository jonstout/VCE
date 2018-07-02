package VCE::Database::Switch;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_switch get_switch get_switches );


sub add_switch {
    my ( $self, $name, $description, $ipv4, $ssh, $netconf,
         $vendor, $model, $version ) = @_;

    $self->{log}->debug("add_switch($name, $description, $ipv4, $ssh, $netconf, $vendor, $model, $version)");

    my $q = $self->{conn}->prepare(
        "insert into switch
         (name, description, ipv4, ssh, netconf, vendor, model, version)
         values (?, ?, ?, ?, ?, ?, ?, ?)"
    );
    $q->execute($name, $description, $ipv4, $ssh, $netconf,
                $vendor, $model, $version);

    return $self->{conn}->last_insert_id("", "", "switch", "");
}

sub get_switch {
    my ( $self, $switch_id ) = @_;

    $self->{log}->debug("get_switch($switch_id)");

    my $q = $self->{conn}->prepare(
        "select * from switch as s
         where s.id=?"
    );
    $q->execute($switch_id);

    my $result = $q->fetchall_arrayref({});
    my $switch = $result->[0];

    my $interfaces = [];
    $switch->{interfaces} = $interfaces;

    return $switch;
}

sub get_switches {
    my ( $self ) = @_;

    $self->{log}->debug("get_switches()");

    my $q = $self->{conn}->prepare(
        "select * from switch"
    );
    $q->execute();

    my $result = $q->fetchall_arrayref({});
    return $result;
}

return 1;
