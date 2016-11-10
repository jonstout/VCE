#!/usr/bin/perl

package VCE::Switch;

use strict;
use warnings;

use Moo;
use GRNOC::Log;

use GRNOC::RabbitMQ::Method;
use GRNOC::RabbitMQ::Dispatcher;
use GRNOC::WebService::Regex;

use VCE::Device;
use VCE::Device::Brocade::MLXe::5_8_0;

has logger => (is => 'rwp');
has device => (is => 'rwp');
has type => (is => 'rwp');
has vendor => (is => 'rwp');
has version => (is => 'rwp');
has username => (is => 'rwp');
has password => (is => 'rwp');
has port => (is => 'rwp');
has hostname => (is => 'rwp');
has dispatcher => (is => 'rwp');
has rabbit_mq => (is => 'rwp');

sub BUILD{
    my ($self) = @_;
    
    my $logger = GRNOC::Log->get_logger("VCE::Switch");
    $self->_set_logger($logger);


    $self->_connect_to_device();

    if(!defined($self->device)){
	$self->logger->error("Error connecting to device");
	return;
    }

    my $dispatcher = GRNOC::RabbitMQ::Dispatcher->new( host => $self->rabbit_mq->{'host'},
						       port => $self->rabbit_mq->{'port'},
						       user => $self->rabbit_mq->{'user'},
						       pass => $self->rabbit_mq->{'pass'},
						       exchange => 'VCE',
						       queue => 'VCE-Switch',
						       topic => 'VCE.Switch.RPC');

    $self->register_rpc_methods( $dispatcher );

    $self->_set_dispatcher($dispatcher);

    return $self;
}



sub _connect_to_device{
    my $self = shift;

    if($self->vendor eq 'Brocade'){
	if($self->type eq 'MLXe'){
	    if($self->version eq '5.8.0'){
		my $dev = VCE::Device::Brocade::MLXe::5_8_0->new( username => $self->username,
								  password => $self->password,
								  hostname => $self->hostname,
								  port => $self->port);

		$dev->connect();
		if($dev->connected){
		    $self->logger->debug( "Successfully connected to device!" );
		    $self->_set_device($dev);
		}else{
		    $self->logger->error( "Error connecting to device");
		    return;
		}
								  
	    }else{
		$self->logger->error( "No supported Brocade MLXe module for version " . $self->version );
		return;
	    }
	}else{
	    $self->logger->error( "No supported Brocade module for devices of type " . $self->type );
	    return;
	}
    }else{
	$self->logger->error( "No supported vendor of type " . $self->vendor );
	return;
    }

}

sub register_rpc_methods{
    my $self = shift;
    my $d = shift;

    my $method = GRNOC::RabbitMQ::Method->new( name => "get_interfaces",
					       callback => sub { return $self->get_interfaces( @_ )  },
					       description => "Get the device interfaces" );

    $method->add_input_parameter( name => "interface_name",
				  description => "Name of the interface to gather data about",
				  required => 0,
				  multiple => 1,
				  pattern => $GRNOC::WebService::Regex::NAME );

    $d->register_method($method);
    
}


sub get_interfaces{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    warn Data::Dumper::Dumper($p_ref);

    if($self->device->connected){
	
	return $self->device->get_interfaces(  );
	
    }else{
	$self->logger->error("Error device is not connected");
	return;
    }
    
}

sub start{
    my $self = shift;
    $self->dispatcher->start_consuming();
    return;
}



1;
