#!/usr/bin/perl

package VCE::Device::Brocade::MLXe::5_8_0;

use strict;
use warnings;

use Moo;
extends 'VCE::Device';

use GRNOC::Comm;

has comm => (is => 'rwp');

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE::Device::Brocade::MLXe::5_8_0");
    $self->_set_logger($logger);

    return $self;
}

sub connect{
    my $self = shift;
    my %params = @_;

    $self->logger->error( "" );
    
    my $comm = GRNOC::Comm->new( host => $self->hostname,
				 user => $self->username,
				 password => $self->password,
				 device => 'brocade',
				 key_delay => .001,
				 debug => 0 );

    $comm->login();
    
    if($comm->connected()){
	$self->_set_comm($comm);
	$self->_set_connected(1);
    }else{
	$self->logger->error( "Error: " . $comm->get_error());
	return;
    }

    return;
}

sub get_interfaces{
    my $self = shift;
    my %params = @_;

    if($self->connected){
	my %interfaces;
	my $interfaces_brief = $self->comm->issue_command('show interfaces brief');
	my $ints = $self->_process_interfaces($interfaces_brief);
	foreach my $int (@$ints){
	    my $int_details = $self->_get_interface( name => $int->{'port_name'});
	    $interfaces{$int_details->{'name'}} = $int_details;
	}
	return \%interfaces;
    }else{
	$self->logger->error("not currently connected to the device");
	return;
    }

}

sub _get_interface{
    my $self = shift;
    my %params = @_;

    my $int_details = $self->comm->issue_command("show interface ethernet" . $params{'name'});
    
    my $int = {};
    foreach my $line (split(/\n/,$int_details)){
	if($line =~ /^\s/){
	    
	    if($line =~ /Hardware is (\S+), address is (\S+)/){
		$int->{'hardware_type'} = $1;
		$int->{'mac_addr'} = $2;
	    }

	    if($line =~ /Configured speed (\S+), actual (\S+), configured duplex (\S+), actual (\S+)/){
		$int->{'speed'} = $2;
	    }

	    if($line =~ /MTU (\d+)/){
		$int->{'mtu'} = $1;
	    }
	    
	    if($line =~ /(\d+) packets input, (\d+) bytes, (\d)/){
		$int->{'input'} = {};
		$int->{'input'}->{'packets'} = $1;
		$int->{'input'}->{'bytes'} = $2;
	    }

	    if($line =~ /(\d+) input errors, (\d+) CRC, (\d+) frame, (\d+) ignored/){
		$int->{'input'}->{'errors'} = $1;
		$int->{'input'}->{'CRC_errors'} = $2;
		$int->{'input'}->{'error_frames'} = $3;
		$int->{'input'}->{'ignored'} = $4;
	    }

	    if($line =~ /(\d+) packets input, (\d+) bytes, (\d)/){
		$int->{'output'} = {};
		$int->{'output'}->{'packets'} = $1;
		$int->{'output'}->{'bytes'} = $2;
	    }

            if($line =~ /(\d+) output errors, (\d+) collisions/){
                $int->{'output'}->{'errors'} = $1;
                $int->{'output'}->{'collisions'} = $2;
            }

	}else{
	    $line =~ /(\S+)\s/;
	    $int->{'name'} = $1;
	}

    }

    return $int;
    
}

sub _process_interfaces{
    my $self = shift;
    my $interfaces_brief = shift;

    my @interfaces;
    foreach my $line (split(/\n/,$interfaces_brief)){
	next if($line =~ /Port/);
	next if($line eq '');

	$line =~ /(\S+)\s+(\S+)\s+(\S+)(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/g;

	my $int = {};
	$int->{'port_name'} = $1;
	$int->{'state'} = $2;
	$int->{'port_state'} = $3;
	$int->{'duplex'} = $4;
	$int->{'speed'} = $5;
	$int->{'trunk'} = $6;
	$int->{'tag'} = $7;
	$int->{'priority'} = $8;
	$int->{'mac'} = $9;
	$int->{'name'} = $10;
	$int->{'type'} = $11;

	push(@interfaces,$int);
    }

    return \@interfaces;
}

1;
