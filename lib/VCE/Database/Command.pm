package VCE::Database::Command;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_command get_commands );

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

sub get_commands {
    my ( $self ) = @_;

    $self->{log}->debug("get_commands()");

    my $q = $self->{conn}->prepare(
        "select * from command"
    );
    $q->execute();

    my $result = $q->fetchall_arrayref({});
    return $result;
}

return 1;
