#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use JSON::XS;

use VCE;
use VCE::Switch;

use GRNOC::Log;
use Types::Standard qw( Str Bool );

use Parallel::ForkManager;
use Proc::Daemon;

use constant DEFAULT_CONFIG_FILE => '/etc/vce/access_policy.xml';
use constant DEFAULT_MODEL_FILE => '/var/run/vce/network_model.sqlite';
use constant DEFAULT_PASSWORD_FILE => '/etc/vce/password.json';

use Data::Dumper;

my @children;
my $vce;
sub usage {
    print "Usage: $0 [--config <file path>] [--model <file path>]\n";
    exit( 1 );
}

# setup signal handlers
$SIG{'TERM'} = sub {
    stop();
};

$SIG{'HUP'} = sub {
    hup();
};

sub stop {
    return kill( 'TERM', @children);
}

sub hup {

}

=head2 get_credentials

    my $creds = get_credentials('/etc/vce/password.json');

get_credentials takes a path to a json file and returns a hash of
switch names to device credentials.

    {
      "switch": {
        "username": "username",
        "password": "password"
      },
      ...
    }

=cut
sub get_credentials {
    my $path = shift;

    my $data = do {
        local $/ = undef;
        open my $fh, "<", $path
            or die "could not open $path: $!";
        <$fh>;
    };

    return decode_json($data);
}

sub main {
    my $config_file = shift;
    my $model_file = shift;
    my $password_file = shift;

    my $log = GRNOC::Log->get_logger("VCE");
    $log->info("access_policy.xml: $config_file");
    $log->info("network_model.sqlite: $model_file");
    $log->info("password.json: $password_file");

    $vce = VCE->new(
        config_file => $config_file,
        network_model_file => $model_file,
        password_file => $password_file
    );

    my $switches = $vce->get_all_switches();
    my $creds    = get_credentials($password_file);

    my $forker = Parallel::ForkManager->new(scalar($switches));
    $forker->run_on_start(
        sub {
            my ($pid) = @_;
            $log->debug( "Child worker process $pid created." );

            push( @children, $pid );
        }
    );

    foreach my $switch (@$switches){
        $forker->start() and next;

        GRNOC::Log->new(config => '/etc/vce/logging.conf');
        my $logger = GRNOC::Log->get_logger("CHILD");

        $logger->debug("Creating switch $switch->{name}.");

        my $s = VCE::Switch->new(
            username => $creds->{$switch->{'name'}}->{'username'},
            password => $creds->{$switch->{'name'}}->{'password'},
            hostname => $switch->{'ip'},
            port => $switch->{'ssh_port'},
            vendor => $switch->{'vendor'},
            type => $switch->{'model'},
            version => $switch->{'version'},
            name => $switch->{'name'},
            rabbit_mq => $vce->rabbit_mq
        );

        $logger->info("Switch $switch->{name} created.");

        if (defined $s) {
            $s->start();
        }

        $forker->finish();
    }

    $forker->wait_all_children();
}

my $config_file = DEFAULT_CONFIG_FILE;
my $model_file = DEFAULT_MODEL_FILE;
my $password_file = DEFAULT_PASSWORD_FILE;
my $help;
my $nofork;

GetOptions( 'config=s' => \$config_file,
            'model=s'  => \$model_file,
            'password=s'  => \$password_file,
            'nofork'   => \$nofork,
            'help|h|?' => \$help );

usage() if $help;

if(!$nofork){

    my $uid = getpwnam('vce');

    my $daemon = Proc::Daemon->new(
        pid_file => "/var/run/vce.pid",
        child_STDOUT => '/var/log/vce.stdout',
        child_STDERR => '/var/log/vce.stderr'
    );

    if($daemon->Status("/var/run/vce.pid")){
        die "Already running";
    }

    my $pid = $daemon->Init();
	GRNOC::Log->new(config => '/etc/vce/logging.conf');
    my $log = GRNOC::Log->get_logger("VCE");

    if (!$pid) {
        $0 = "VCE";
        $> = $uid;

        eval {
            main($config_file, $model_file, $password_file);
        };
        if ($@) {
            $log->fatal("Fatal exception raised: $@");
            exit 1;
        }
    } else {
        $log->info("VCE Initialization Forked. Starting VCE [$pid].");
    }
}else{
    GRNOC::Log->new(config => '/etc/vce/logging.conf');
    my $log = GRNOC::Log->get_logger("VCE");

    $log->info("VCE Initialization Fork Skipped.");
    eval {
        main($config_file, $model_file, $password_file);
    };
    if ($@) {
        $log->fatal("Fatal exception raised: $@");
        exit 1;
    }
}

exit 0;
