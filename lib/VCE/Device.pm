#!/usr/bin/perl

package VCE::Device;

use strict;
use warnings;

use Moo;
use GRNOC::Log;

has logger => (is => 'rwp');
has username => (is => 'rwp');
has password => (is => 'rwp');
has port => (is => 'rwp');
has connected => (is => 'rwp',
		  default => 0);
has hostname => (is => 'rwp');

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE::Device");
    $self->_set_logger($logger);
    
    return $self;
}

sub connect{
    my $self = shift;
    $self->logger->error("Connect has not been overridden");
    return;
}

sub get_interfaces{
    my $self = shift;
    $self->logger->error("Get interfaces has not been overridden");
    return;
}

sub get_light_levels{
    my $self = shift;
    $self->logger->error("Get light levels has not been overridden");
    return;
}



1;
