#!/usr/bin/perl

package VCE::Switch;

use strict;
use warnings;

use Moo;
use GRNOC::Log;

has logger => (is => 'rwp');

sub BUILD{
    my ($self) = @_;
    
    my $logger = GRNOC::Log->get_logger("VCE::Switch");
    $self->_set_logger($logger);

    return $self;
}




1;
