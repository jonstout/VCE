package VCE::Database::Parameter;

use strict;
use warnings;

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
    my ( $self ) = @_;

    $self->{log}->debug("get_parameters()");

    my $q = $self->{conn}->prepare(
        "select * from parameter"
    );
    $q->execute();

    my $result = $q->fetchall_arrayref({});
    return $result;
}

return 1;
