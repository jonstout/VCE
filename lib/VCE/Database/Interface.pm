package VCE::Database::Interface;

use strict;
use warnings;
use Data::Dumper;
use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_interface get_interface get_interfaces update_interface delete_interface);


=head2 add_interface

    my $id = add_interface(
      admin_up => 0,
      description => '',
      hardware_type => '100GigabitEthernet',
      link_up => 1,
      mac_addr => 'cc4e.240c.0cc1',
      mtu => '9216',
      name => 'ethernet 5/2',
      workgroup_id => 1,
      speed => 'unknown',
      switch_id => 1
    );

=cut
sub add_interface {
    my $self   = shift;
    my %params = @_;
    # warn Dumper(%params);
    return if (!defined $params{description});
    return if (!defined $params{name});
    return if (!defined $params{switch_id});

    $self->{log}->debug("add_interface($params{name}, $params{description}, $params{switch_id})");

    eval {
        my $q = $self->{conn}->prepare(
            "insert into interface (
               admin_up, description, hardware_type, link_up,
               mac_addr, mtu, name, workgroup_id, speed, switch_id
             ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
        );

        $q->execute(
            $params{admin_up} || 0,
            $params{description} || '',
            $params{hardware_type},
            $params{link_up} || 0,
            $params{mac_addr},
            $params{mtu},
            $params{name},
            $params{workgroup_id} || 1,
            $params{speed} || 'unknown',
            $params{switch_id}
        );
    };
    if ($@) {
        $self->{log}->error("$@");
        return (undef,"$@")
    }

    my $id = $self->{conn}->last_insert_id("", "", "interface", "");
    return ($id, undef);
}

=head2 delete_interface


=cut
sub delete_interface {
    my $self = shift;
    my $interface_id = shift;

    $self->{log}->debug("Calling delete_interface");

    if (!defined $interface_id) {
        $self->{log}->error("No interface id specified");
        return;
    }

    eval {
        my $query = $self->{conn}->prepare(
            'DELETE FROM interface WHERE id=?'
        );
        $query->execute($interface_id);
    };
    if ($@) {
        warn Dumper($@);
        $self->{log}->error("$@");
        return 0;
    }

    return 1;
}

=head2 get_interface


=cut
sub get_interface {
    my ( $self, $interface_id ) = @_;

    $self->{log}->debug("get_interface($interface_id)");

    my $q = $self->{conn}->prepare(
        "select * from interface as i
         where i.id=?"
    );
    $q->execute($interface_id);

    my $result = $q->fetchall_arrayref({});
    my $interface = $result->[0];

#    my $vlans = get_vlan_acls($workgroup_id, $interface_id);
    $interface->{vlans} = [];

    return $interface;
}

=head2 get_interfaces


=cut
sub get_interfaces {
    my $self = shift;
    my %params = @_;

    $self->{log}->debug("get_interfaces( )");

    my $keys = [];
    my $args = [];

    if (defined $params{switch_id}) {
        push @$keys, 'switch_id=?';
        push @$args, $params{switch_id};
    }
    if (defined $params{name}) {
        push @$keys, 'name=?';
        push @$args, $params{name};
    }
    if (defined $params{workgroup_id}) {
        push @$keys, 'workgroup_id=?';
        push @$args, $params{workgroup_id};
    }

    my $values = join(' AND ', @$keys);
    my $where = scalar(@$keys) > 0 ? "WHERE $values" : "";

    my $q = $self->{conn}->prepare(
        "SELECT * FROM interface $where"
    );
    $q->execute(@$args);

    my $result = $q->fetchall_arrayref({});
    return $result;
}

=head2 update_interface

    my $ok = update_interface(
      id => 1,
      admin_up => 0,
      description => '',
      hardware_type => '100GigabitEthernet',
      link_up => 1,
      mac_addr => 'cc4e.240c.0cc1',
      mtu => '9216',
      name => 'ethernet 5/2',
      workgroup_id => 1,
      speed => 'unknown',
      switch_id => 1
    );

=cut
sub update_interface {
    my $self   = shift;
    my %params = @_;
    return if (!defined $params{id});

    $self->{log}->debug("update_interface($params{id}, ...)");

    my $keys = [];
    my $args = [];

    if (defined $params{admin_up}) {
        push @$keys, 'admin_up=?';
        push @$args, $params{admin_up};
    }
    if (defined $params{description}) {
        push @$keys, 'description=?';
        push @$args, $params{description};
    }
    if (defined $params{hardware_type}) {
        push @$keys, 'hardware_type=?';
        push @$args, $params{hardware_type};
    }
    if (defined $params{link_up}) {
        push @$keys, 'link_up=?';
        push @$args, $params{link_up};
    }
    if (defined $params{mac_addr}) {
        push @$keys, 'mac_addr=?';
        push @$args, $params{mac_addr};
    }
    if (defined $params{mtu}) {
        push @$keys, 'mtu=?';
        push @$args, $params{mtu};
    }
    if (defined $params{name}) {
        push @$keys, 'name=?';
        push @$args, $params{name};
    }
    if (defined $params{workgroup_id}) {
        push @$keys, 'workgroup_id=?';
        push @$args, $params{workgroup_id};
    }
    if (defined $params{speed}) {
        push @$keys, 'speed=?';
        push @$args, $params{speed};
    }

    my $values = join(', ', @$keys);
    push @$args, $params{id};
    my $result;
    eval {
        my $q = $self->{conn}->prepare(
            "UPDATE interface SET $values WHERE id=?"
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
