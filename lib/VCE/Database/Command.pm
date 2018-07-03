package VCE::Database::Command;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_command );

sub add_command {
    my ( $self, $name, $description, $role, $template ) = @_;

    $self->{log}->debug("add_command($name, $description, $role, $template)");

    my $q = $self->{conn}->prepare(
        "insert into command
         (name, description, role, template)
         values (?, ?, ?, ?)"
    );
    $q->execute($name, $description, $role, $template);

    return $self->{conn}->last_insert_id("", "", "command", "");
}
