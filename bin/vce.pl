#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;

use VCE;
use VCE::Switch;

use GRNOC::Log;
use Types::Standard qw( Str Bool );

use Parallel::ForkManager;
use Proc::Daemon;
use constant DEFAULT_CONFIG_FILE => '/etc/vce/access_policy.xml';
use constant DEFAULT_MODEL_FILE => '/var/run/vce/network_model.json';

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

sub stop{
    return kill( 'TERM', @children);
}

sub hup{
    
}

sub main{
    my $config_file = shift;
    my $model_file = shift;

    my $log = GRNOC::Log->get_logger("VCE");
    $log->error("HERE!!");

    $log->error(Dumper($config_file));
    $log->error(Dumper($model_file));
    $vce = VCE->new( config_file => $config_file,
                     model_file => $model_file);
    
    
    my $switches = $vce->get_all_switches();
    
    my $forker = Parallel::ForkManager->new( scalar($switches) );

    $forker->run_on_start( sub {
	
        my ( $pid ) = @_;
	
        $log->debug( "Child worker process $pid created." );
	
        push( @children, $pid );
			   } );

    foreach my $switch (@$switches){
        $forker->start() and next;        

        GRNOC::Log->new( config => '/etc/vce/logging.conf');
        my $logger = GRNOC::Log->get_logger("CHILD");
	$logger->error("Creating switch!!!");
	my $s = VCE::Switch->new( username => $switch->{'username'},
                                  password => $switch->{'password'},
                                  hostname => $switch->{'ip'},
                                  port => $switch->{'ssh_port'},
                                  vendor => $switch->{'vendor'},
                                  type => $switch->{'model'},
                                  version => $switch->{'version'},
                                  name => $switch->{'name'},
                                  rabbit_mq => $vce->rabbit_mq );

	$logger->error("Switch Instance created!");
        
        if(defined($s)){
            $s->start();
        }

        $forker->finish();
    }

    
    $forker->wait_all_children();

    

}

my $config_file = DEFAULT_CONFIG_FILE;
my $model_file = DEFAULT_MODEL_FILE;
my $help;
my $nofork;

GetOptions( 'config=s' => \$config_file,
            'model=s'  => \$model_file,
	    'nofork'   => \$nofork,
            'help|h|?' => \$help );

usage() if $help;

if(!$nofork){

    my $uid = getpwnam('vce');

    my $daemon = Proc::Daemon->new( pid_file => "/var/run/vce.pid" );

    if($daemon->Status("/var/run/vce.pid")){
        die "Already running";
    }

    my $pid = $daemon->Init();
    if ( !$pid ) {
	$0 = "VCE";
        $> = $uid;
	GRNOC::Log->new( config => '/etc/vce/logging.conf');
	main($config_file, $model_file);
    }


}else{
    GRNOC::Log->new( config => '/etc/vce/logging.conf');
    main($config_file, $model_file);
}

