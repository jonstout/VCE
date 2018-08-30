#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use JSON::XS;

use VCE::Database::Connection;
use VCE;
use VCE::Switch;

use GRNOC::Log;
use Types::Standard qw( Str Bool );

use Proc::Daemon;

use GRNOC::RabbitMQ::Dispatcher;
use GRNOC::RabbitMQ::Method;
use AnyEvent::Fork;

use constant DEFAULT_CONFIG_FILE => '/etc/vce/access_policy.xml';
# use constant DEFAULT_MODEL_FILE => '/var/lib/vce/network_model.sqlite';
use constant DEFAULT_MODEL_FILE => '/var/lib/vce/database.sqlite';
use constant DEFAULT_PASSWORD_FILE => '/etc/vce/password.json';

use Data::Dumper;

my @children;
my $vce;
my $d;
sub usage {
    print "Usage: $0 [--config <file path>] [--model <file path>]\n";
    exit( 1 );
}

# setup signal handlers
$SIG{'TERM'} = sub {
    $d->stop();
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

sub make_switch_process{
    my $switch = shift;
    my $creds = shift;
    
    my %args;
    foreach my $key (keys (%{$switch})){
	$args{$key} = $switch->{$key};
    }

    foreach my $key (keys (%{$vce->rabbit_mq})){
        $args{$key} = $vce->rabbit_mq->{$key};
    }

    foreach my $key (keys (%{$creds->{$switch->{'name'}}})){
        $args{$key} = $creds->{$switch->{'name'}}->{$key};
    }

    my $proc = AnyEvent::Fork->new->require("GRNOC::Log","VCE::Switch")->eval('
        use strict;
        use warnings;
        use Data::Dumper;
        GRNOC::Log->new(config => "/etc/vce/logging.conf");
        my $logger = GRNOC::Log->get_logger("CHILD");
        $logger->debug("Creating switch");
	
        sub run{
            my $fh = shift;
	    my %args = @_;
	    
	    my $rabbit_mq = { host => $args{"host"}, 
			      port => $args{"port"}, 
			      user => $args{"user"}, 
			      pass => $args{"pass"}};
	    
            my $s = VCE::Switch->new(
                username => $args{"username"},
                password => $args{"password"},
                hostname => $args{"ipv4"},
                port => $args{"ssh"},
                vendor => $args{"vendor"},
                type => $args{"model"},
                version => $args{"version"},
                name => $args{"name"},
                rabbit_mq => $rabbit_mq,
                id => $args{"id"}
                );

            $logger->info("Switch $args{\"name\"} created.");

            if (defined $s) {
                $s->start();
            }
        }')->send_arg( %args  )->run("run");
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

    my $db = VCE::Database::Connection->new('/var/lib/vce/database.sqlite');
    my $switches = $db->get_switches();
    my $creds    = get_credentials($password_file);

    foreach my $switch (@$switches){
	warn "Making Switch: " . Dumper($switch);
	make_switch_process( $switch, $creds );
    }

    $d = GRNOC::RabbitMQ::Dispatcher->new( host     => $vce->rabbit_mq->{'host'},
					      port     => $vce->rabbit_mq->{'port'},
					      user     => $vce->rabbit_mq->{'user'},
					      pass     => $vce->rabbit_mq->{'pass'},
					      exchange => 'VCE',
					      queue    => 'VCE-Main',
					      topic    => 'VCE'
	);
    
    my $method = GRNOC::RabbitMQ::Method->new(
        name => "add_switch",
        callback => sub { 
	    my %params = @_;
	    my $switch = $db->get_switch(switch_id => $params{'switch_id'}{'value'} );
	    if(!defined($switch)){
		return {success => 0};
	    }
	    
	    my $res = make_switch_process( $switch, $creds );

	    return {success => 1};
	},
        description => "adds a switch process"
	);

    $method->add_input_parameter(
        name => "switch_id",
        description => "ID of the switch to start a process for",
        required => 1,
        multiple => 0,
        pattern => $GRNOC::WebService::Regex::NUMBER_ID
	);
    $d->register_method($method);

    $d->start_consuming();

    return;
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
