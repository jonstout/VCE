package VCE::Database::Connection;

use strict;
use warnings;

use DBI;
use GRNOC::Log;

use VCE::Database::ACL;
use VCE::Database::Command;
use VCE::Database::Interface;
use VCE::Database::Parameter;
use VCE::Database::Switch;
use VCE::Database::Tag;
use VCE::Database::User;
use VCE::Database::VLAN;
use VCE::Database::Workgroup;

=head1 VCE::Database::Connection

    use VCE::Database::Connection

=cut

=head2 new

    my $db = VCE::Database::Connection->new('/var/lib/vce/database.sqlite');

=cut
sub new {
    my $class = shift;
    my ( $path ) = @_;

    my $logger = GRNOC::Log->new(
        config => '/etc/vce/logging.conf',
        watch => 5
    );

    my $conn = DBI->connect(
        "dbi:SQLite:dbname=$path",
        undef,
        undef,
        { AutoCommit => 1, RaiseError => 1, sqlite_see_if_its_a_number => 1 }
    );

    my $self = bless {
        conn => $conn,
        log => $logger->get_logger("VCE.Database.Connection"),
        path => $path
    }, $class;

    return $self;
}

return 1;
