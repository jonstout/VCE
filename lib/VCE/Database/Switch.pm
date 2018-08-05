package VCE::Database::Switch;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_switch get_switch get_switches );


=head1 Package VCE::Database::Switch

    use VCE::Database::Switch

=cut

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

=head2 get_switches

get_switches returns an array of switch hashs.

    {
        id => 1,
        name => 'mlxe16-1.sdn-test.grnoc.iu.edu',
        description => 'testlab',
        ipv4 => '192.168.1.1',
        ssh => 22,
        netconf => 830,
        vendor => 'Brocade',
        model => 'MLXe',
        version => '5.8.0'
    }

=cut
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
