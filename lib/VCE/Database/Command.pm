package VCE::Database::Command;

use strict;
use warnings;
use Data::Dumper;
use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_command get_commands add_command_to_switch delete_command modify_command);

=head2 delete_command

=cut

sub delete_command{
    my $self = shift;
    my %params = @_;
    
    warn Dumper(\%params);
    my $command_id = $params{'command_id'};
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
    
    my $command_id = $params{'command_id'};
    my $name = $params{'name'};
    my $description = $params{'description'};
    my $operation = $params{'operation'};
    my $type = $params{'type'};
    my $template = $params{'template'};

    my $cmd_q = $self->{conn}->prepare("select * from command where id = ?");
    $cmd_q->execute($command_id);
    my $res = $cmd_q->fetchall_arrayref({});

    warn Dumper(\%params);
    warn Dumper($res);

    if(!defined($res) || !defined($res->[0])){
	#unable to find the instance to update
	return;
    }

    if(!defined($name)){
	$name = $res->[0]->{'name'};
    }

    if(!defined($description)){
	$description = $res->[0]->{'description'};
    }

    if(!defined($operation)){
        $operation = $res->[0]->{'operation'};
    }

    if(!defined($description)){
        $type = $res->[0]->{'type'};
    }

    if(!defined($template)){
        $template = $res->[0]->{'template'};
    }

    my $q = $self->{conn}->prepare("update command set name = ?, description = ?, operation = ?, type = ?, template = ? where id = ?");
    
    return $q->execute($name, $description, $operation, $type, $template, $command_id);
    
    
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

    if (defined $params{switch_id}) {
        push @$keys, 'switch_command.switch_id=?';
        push @$args, $params{switch_id};
    }
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
