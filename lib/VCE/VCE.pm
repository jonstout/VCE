#!/usr/bin/perl

package VCE;

use strict;
use warnings;

use Moo;
use GRNOC::Log;
use GRNOC::Config;
use GRNOC::RabbitMQ;

has config_file => (is => 'rwp');
has config => (is => 'rwp');
has logger => (is => 'rwp');
has access => (is => 'rwp');

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE");
    $self->_set_logger($logger);
    
    $self->_process_config();

    $self->_set_access( VCE::Access->new( config => $self->config,
					  logger => $self->logger ));
    
    return $self;
}

sub _process_config{
    my $self = shift;

    my $config = GRNOC::Config->new( config_file => $self->config_file);
    
    my %workgroups;
    my %users;

    my $wgs = $config->get('/accessPolicy/workgroup');
    foreach my $workgroup (@$wgs){
	$self->logger->debug("Processing workgroup: " . Data::Dumper::Dumper($workgroup));
	my $grp = {};
	$grp->{'name'} = $workgroup->{'name'};
	$grp->{'description'} = $workgroup->{'description'};
	$grp->{'user'} = $workgroup->{'user'};
	$workgroups{$grp->{'name'}} = $grp;
	foreach my $user (@{$grp->{'user'}}){
	    if(!defined($users{$user})){
		$users{$user} = ();
	    }
	    push(@{$users{$user}},$grp->{'name'});
	}
    }
    
    my $cfg = {};
    $cfg->{'users'} = \%users;
    $cfg->{'workgroups'} = \%workgroups;
    
    my %switches;
    my $switches = $config->get('/accessPolicy/switch');
    foreach my $switch (@$switches){
	$self->logger->debug("Processing switch: " . Data::Dumper::Dumper($switch));
	$switches{$switch->{'name'}} = $switch;
    }

    $cfg->{'switches'} = \%switches;
    $self->_set_config($cfg);
    $self->logger->debug("Config: " . Data::Dumper::Dumper($self->config));

}


1;
