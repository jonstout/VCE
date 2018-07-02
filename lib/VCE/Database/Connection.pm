package VCE::Database::Connection;

use strict;
use warnings;

use DBI;
use GRNOC::Log;

use VCE::Database::Interface;
use VCE::Database::Switch;
use VCE::Database::User;
use VCE::Database::VLAN;
use VCE::Database::Workgroup;

sub new {
    my $class = shift;
    my ( $path ) = @_;

    my $logger = GRNOC::Log->new(
        config => '/etc/vce/logging.conf',
        watch => 5
    );
    my $log = $logger->get_logger("VCE.Database.Connection");

    my $conn = DBI->connect(
        "dbi:SQLite:dbname=$path",
        undef,
        undef,
        { AutoCommit => 1, RaiseError => 1, sqlite_see_if_its_a_number => 1 }
    );

    my $self = bless {
        conn => $conn,
        log => $log,
        path => $path
    }, $class;

    return $self;
}

return 1;
