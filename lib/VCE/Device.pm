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

=head2 BUILD

=over 4

=item hostname

=item logger

=item username

=item password

=item port

=item connected

=back

=cut

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE::Device");
    $self->_set_logger($logger);
    
    return $self;
}

=head2 connect

=cut

sub connect{
    my $self = shift;
    $self->logger->error("Connect has not been overridden");
    return;
}

=head2 get_interfaces

=cut

sub get_interfaces{
    my $self = shift;
    $self->logger->error("Get interfaces has not been overridden");
    return;
}

=head2 get_light_levels

=cut

sub get_light_levels{
    my $self = shift;
    $self->logger->error("Get light levels has not been overridden");
    return;
}



1;
