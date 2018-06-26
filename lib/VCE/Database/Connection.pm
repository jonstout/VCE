package Database::Connection;

use strict;
use warnings;

use DBI;
use GRNOC::Log;

use Database::Interface;
use Database::Switch;
use Database::VLAN;

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
