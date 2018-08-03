package VCE::Database::Command;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_command get_commands add_command_to_switch);

sub add_command {
    my ( $self, $name, $description, $type, $template ) = @_;

    $self->{log}->debug("add_command($name, $description, $type, $template)");

    my $q = $self->{conn}->prepare(
        "insert into command
         (name, description, type, template)
         values (?, ?, ?, ?)"
    );
    $q->execute($name, $description, $type, $template);

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

sub add_command_to_switch {
    my ( $self, $command_id, $switch_id, $role ) = @_;

    $self->{log}->debug("add_command_to_switch($command_id, $switch_id, $role)");

    my $q = $self->{conn}->prepare(
        "insert into switch_command
         (command_id, switch_id, role)
         values (?, ?, ?)"
    );
    $q->execute($command_id, $switch_id, $role);

    return $self->{conn}->last_insert_id("", "", "switch_command", "");
}

return 1;
