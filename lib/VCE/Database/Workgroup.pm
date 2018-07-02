package VCE::Database::Workgroup;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_workgroup get_workgroup get_workgroups );


sub add_workgroup {
    my ( $self, $name, $description ) = @_;

    $self->{log}->debug("add_workgroup($name, $description)");

    my $q = $self->{conn}->prepare(
        "insert into workgroup (name, description) values (?, ?)"
    );
    $q->execute($name, $description);

    return $self->{conn}->last_insert_id("", "", "workgroup", "");
}

sub get_workgroup {
    my $self = shift;
    my %params = @_;

    my $reqs = [];
    my $args = [];
    my $where = '';

    if (defined $params{id}) {
        push @$reqs, 'id=?';
        push @$args, $params{id};
    }
    if (defined $params{name}) {
        push @$reqs, 'name=?';
        push @$args, $params{name};
    }
    $where .= join(' AND ', @$reqs);

    my $q = $self->{conn}->prepare(
        "select * from workgroup WHERE $where",
    );
    $q->execute(@$args);

    my $result = $q->fetchall_arrayref({})->[0];
    return $result;
}

sub get_workgroups {
    my ( $self ) = @_;

    $self->{log}->debug("get_workgroups()");

    my $q = $self->{conn}->prepare(
        "select * from workgroup"
    );
    $q->execute();

    my $result = $q->fetchall_arrayref({});
    return $result;
}

return 1;