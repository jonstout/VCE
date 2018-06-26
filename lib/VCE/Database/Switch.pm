package Database::Switch;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( get_switch );


sub get_switch {
    my ( $self, $switch_id ) = @_;

    $self->{log}->debug("get_switch($self->{conn}, $switch_id)");

    my $q = $self->{conn}->prepare(
        "select * from switch as s
         where s.switch_id=?"
    );
    $q->execute($switch_id);

    my $result = $q->fetchall_arrayref({});
    my $switch = $result->[0];

    my $interfaces = get_interfaces($switch_id);
    $switch->{interfaces} = $interfaces;

    return $switch;
}

return 1;
