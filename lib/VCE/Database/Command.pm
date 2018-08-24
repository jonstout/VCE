package VCE::Database::Command;

use strict;
use warnings;
use Data::Dumper;
use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_command get_commands add_command_to_switch);

=head2 add_command
=cut
sub add_command {
    my ( $self, $name, $description, $operation, $type, $template ) = @_;

    $self->{log}->debug("add_command($name, $description, $operation, $type, $template)");

    my $q = $self->{conn}->prepare(
        "insert into command
         (name, description, operation, type, template)
         values (?, ?, ?, ?, ?)"
    );
    $q->execute($name, $description, $operation, $type, $template);

    return $self->{conn}->last_insert_id("", "", "command", "");
}

=head2 get_commands
=cut
sub get_commands {
    my $self = shift;
    my %params = @_;

    $self->{log}->debug("get_commands()");

    my $keys = [];
    my $args = [];

    if (defined $params{switch_id}) {
        push @$keys, 'switch_command.switch_id=?';
        push @$args, $params{switch_id};
    }
    if (defined $params{type}) {
        push @$keys, 'command.type=?';
        push @$args, $params{type};
    }

    my $values = join(' AND ', @$keys);
    my $where = scalar(@$keys) > 0 ? "WHERE $values" : "";

    my $q = $self->{conn}->prepare(
        "select * from command
         left join switch_command on switch_command.command_id=command.id
         $where"
    );
    $q->execute(@$args);

    my $result = $q->fetchall_arrayref({});
    return $result;
}

=head2 add_command_to_switch
=cut
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
