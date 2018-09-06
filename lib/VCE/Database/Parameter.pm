package VCE::Database::Parameter;

use strict;
use warnings;

use Data::Dumper;
use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_parameter get_parameters update_parameter );

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

=head2 update_parameter

=cut
sub update_parameter {
    my $self   = shift;
    my %params = @_;

    if (!defined $params{id}) {
        $self->{log}->error("Parameter id not specified.");
        return 0;
    }
    $self->{log}->debug("update_parameter($params{id}, ...)");

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
    if (defined $params{regex}) {
        push @$keys, 'regex=?';
        push @$args, $params{regex};
    }
    if (defined $params{type}) {
        push @$keys, 'type=?';
        push @$args, $params{type};
    }

    my $values = join(', ', @$keys);
    push @$args, $params{id};
    my $result;

    eval {
        my $q = $self->{conn}->prepare(
            "update parameter set $values where id=?"
        );
        $result = $q->execute(@$args);
    };
    if ($@) {
        $self->{log}->error("$@");
        return 0;
    }
    return $result;
}

return 1;
