package VCE::Database::Switch;

use strict;
use warnings;
use Data::Dumper;
use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_switch get_switch get_switches modify_switch delete_switch);


sub add_switch {
    my ( $self, $name, $description, $ipv4, $ssh, $netconf,
        $vendor, $model, $version ) = @_;

    $self->{log}->debug("add_switch($name, $description, $ipv4, $ssh, $netconf, $vendor, $model, $version)");


    eval {
        my $q = $self->{conn}->prepare(
            "insert into switch
            (name, description, ipv4, ssh, netconf, vendor, model, version)
            values (?, ?, ?, ?, ?, ?, ?, ?)"
        );
        $q->execute($name, $description, $ipv4, $ssh, $netconf,
            $vendor, $model, $version);
    };

    if ( $@) {
        return (undef,"$@")
    }

    my $id = $self->{conn}->last_insert_id("", "", "switch", "");
    return ($id, undef);
}

sub get_switch {
    my ( $self, $switch_id ) = @_;

    $self->{log}->debug("get_switch($switch_id)");

    my $q = $self->{conn}->prepare(
        "select * from switch as s
        where s.id=?"
    );
    $q->execute($switch_id);

    my $result = $q->fetchall_arrayref({});
    my $switch = $result->[0];

    my $interfaces = [];
    $switch->{interfaces} = $interfaces;

    return $switch;
}

sub get_switches {
    my ( $self ) = @_;

    $self->{log}->debug("get_switches()");

    my $q = $self->{conn}->prepare(
        "select * from switch"
    );
    $q->execute();

    my $result = $q->fetchall_arrayref({});
    return $result;
}


sub modify_switch {
    my $self   = shift;
    my %params = @_;
    warn Dumper($params{name});

    return if (!defined $params{id});

    $self->{log}->debug("modify_switch($params{id}, ...)");

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

    if (defined $params{ip}) {
        push @$keys, 'ipv4=?';
        push @$args, $params{ip};
    }
    if (defined $params{ssh}) {
        push @$keys, 'ssh=?';
        push @$args, $params{ssh};
    }
    if (defined $params{netconf}) {
        push @$keys, 'netconf=?';
        push @$args, $params{netconf};
    }
    if (defined $params{vendor}) {
        push @$keys, 'vendor=?';
        push @$args, $params{vendor};
    }
    if (defined $params{model}) {
        push @$keys, 'model=?';
        push @$args, $params{model};
    }
    if (defined $params{version}) {
        push @$keys, 'version=?';
        push @$args, $params{version};
    }

    my $values = join(', ', @$keys);
    push @$args, $params{id};

    my $q = $self->{conn}->prepare(
        "UPDATE switch  SET $values WHERE id=?"
    );
    return $q->execute(@$args);
}

sub delete_switch {
    my $self   = shift;
    my %params = @_;

    return if (!defined $params{id});

    $self->{log}->debug("delete_switch($params{id}, ...)");

    my $keys = [];
    my $args = [];

    push @$args, $params{id};

    my $q = $self->{conn}->prepare(
        "DELETE FROM switch WHERE id=?"
    );
    return $q->execute(@$args);
}
return 1;
