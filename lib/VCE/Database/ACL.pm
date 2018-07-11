package VCE::Database::ACL;

use strict;
use warnings;

use Exporter;

our @ISA = qw( Exporter );
our @EXPORT = qw( add_acl get_acls );


sub add_acl {
    my ( $self, $workgroup_id, $interface_id, $low, $high ) = @_;

    $self->{log}->debug("add_acl($workgroup_id, $interface_id, $low, $high)");

    my $q = $self->{conn}->prepare(
        "insert into interface_workgroup_acl
         (interface_id, workgroup_id, low, high)
         values (?, ?, ?, ?)"
    );
    $q->execute($interface_id, $workgroup_id, $low, $high);

    return $self->{conn}->last_insert_id("", "", "interface_workgroup_acl", "");
}

sub get_acls {
    my ( $self, $workgroup_id, $interface_id ) = @_;

    $self->{log}->debug("get_acls($self->{conn}, $workgroup_id, $interface_id)");

    my $q = $self->{conn}->prepare(
        "select * from interface_workgroup_acl as iwa
         where iwa.workgroup_id=? and iwa.interface_id=?"
    );
    $q->execute($workgroup_id, $interface_id);

    my $acls = $q->fetchall_arrayref({});
    my $result = [];

    foreach my $acl (@$acls) {
        push @$result, { high => $acl->{high}, low  => $acl->{low} };
    }

    return $result;
}

return 1;
