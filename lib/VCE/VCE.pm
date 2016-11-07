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

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE");
    $self->_set_logger($logger);
    
    $self->process_config();

    
    
    return $self;
}

sub process_config{
    my $self = shift;

    my $config = GRNOC::Config->new( config_file => $self->config_file);
    
    
}



1;
