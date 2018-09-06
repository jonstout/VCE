package VCE::Database::Command;

use strict;
use warnings;
use Data::Dumper;
use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_command get_commands delete_command modify_command get_assigned_commands );

=head2 delete_command

=cut
sub delete_command{
    my $self = shift;
    my $command_id = shift;

    if(!defined($command_id)){
        return "No command ID specified";
    }

    my $q = $self->{conn}->prepare("delete from command where id = ?");
    my $res = $q->execute($command_id);
    return $res;
}

=head2 modify_command

=cut
sub modify_command{
    my $self = shift;
    my %params = @_;

    if (!defined $params{id}) {
        $self->{log}->error("Command ID not specified.");
        return 0;
    }

    $self->{log}->debug("modify_command($params{id}, ...)");

    my $keys = [];
    my $args = [];

    if (defined $params{name}) {
        push @$keys, 'name=?';
        push @$args, $params{name};
    }
    if (defined $params{description}) {
        push @$keys, 'description=?';
        push @$args, $params{description};
    }
    if (defined $params{operation}) {
        push @$keys, 'operation=?';
        push @$args, $params{operation};
    }
    if (defined $params{type}) {
        push @$keys, 'type=?';
        push @$args, $params{type};
    }
    if (defined $params{template}) {
        push @$keys, 'template=?';
        push @$args, $params{template};
    }

    my $values = join(', ', @$keys);
    push @$args, $params{id};
    my $result;
    eval {
        my $q = $self->{conn}->prepare(
            "update command set $values where id=?"
        );

        $result = $q->execute(@$args);
    };
    if ($@) {
        $self->{log}->error("$@");
        return 0;
    }
    return $result;
}

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

    if (defined $params{type}) {
        push @$keys, 'command.type=?';
        push @$args, $params{type};
    }
    if(defined($params{command_id})){
        push @$keys, 'command.id=?';
        push @$args, $params{command_id};
    }

    my $values = join(' AND ', @$keys);
    my $where = scalar(@$keys) > 0 ? "WHERE $values" : "";

    my $q = $self->{conn}->prepare(
        "select * from command
         $where
         order by name"
    );
    $q->execute(@$args);

    my $result = $q->fetchall_arrayref({});
    return $result;
}

=head2 get_assigned_commands
=cut
sub get_assigned_commands {
    my $self = shift;
    my %params = @_;

    my $keys = [];
    my $outer_keys = [];
    my $args = [];

    if (defined $params{switch_id}) {
        push @$keys, 'switch_command.switch_id=?';
        push @$args, $params{switch_id};
    }
    if (defined $params{type}) {
        push @$outer_keys, 'command.type=?';
        push @$args, $params{type};
    }

    my $values = join(' AND ', @$keys);
    my $where = scalar(@$keys) > 0 ? "WHERE $values" : "";
    my $outer_values = join(' AND ', @$outer_keys);
    my $outer_where = scalar(@$outer_keys) > 0 ? "WHERE $outer_values" : "";

    my $q = $self->{conn}->prepare(
        "select command.*, a.id as switch_command_id,  a.role from command
         left join (
           select * from switch_command $where
         ) a on command.id=a.command_id
         $outer_where"
    );
    $q->execute(@$args);

    my $result = $q->fetchall_arrayref({});
    return $result;
}

return 1;
