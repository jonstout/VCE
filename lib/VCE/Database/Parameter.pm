package VCE::Database::Parameter;

use strict;
use warnings;

use Data::Dumper;
use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_parameter get_parameters );

=head2 add_parameter


=cut
sub add_parameter {
    my ( $self, $command_id, $name, $description, $regex, $type ) = @_;

    $self->{log}->debug("add_parameter($command_id, $name, $description, $regex, $type)");

    my $q = $self->{conn}->prepare(
        "insert into parameter
         (command_id, name, description, regex, type)
         values (?, ?, ?, ?, ?)"
    );
    $q->execute($command_id, $name, $description, $regex, $type);

    return $self->{conn}->last_insert_id("", "", "parameter", "");
}

=head2 get_parameters


=cut
sub get_parameters {
    my $self = shift;
    my %params = @_;

    $self->{log}->debug("get_parameters()");

    my $keys = [];
    my $args = [];

    if (defined $params{command_id}) {
        push @$keys, 'command_id=?';
        push @$args, $params{command_id};
    }
    if (defined $params{type}) {
        push @$keys, 'type=?';
        push @$args, $params{type};
    }

    my $values = join(' AND ', @$keys);
    my $where = scalar(@$keys) > 0 ? "WHERE $values" : "";

    my $q = $self->{conn}->prepare(
        "select * from parameter $where"
    );
    $q->execute(@$args);

    my $result = $q->fetchall_arrayref({});
    return $result;
}

return 1;
