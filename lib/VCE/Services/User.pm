#!/usr/bin/perl
package VCE::Services::User;

use strict;
use warnings;

use Moo;
use GRNOC::Log;
use GRNOC::WebService::Dispatcher;
use GRNOC::WebService::Method;
use GRNOC::WebService::Regex;

use VCE::Access;
use VCE::Database::Connection;

has vce => (is => 'rwp');
has db => (is => 'rwp');
has logger => (is => 'rwp');
has dispatcher => (is => 'rwp');

=head2 BUILD

=over 4

=item access

=item db

=item dispatcher

=item logger

=item vce

=back

=cut

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf', watch => 15);
    my $log    = $logger->get_logger("VCE::Services::User");
    $self->_set_logger($log);

    $self->_set_vce( VCE->new() );

    my $dispatcher = GRNOC::WebService::Dispatcher->new();
    $self->_set_db(VCE::Database::Connection->new('/var/lib/vce/database.sqlite'));

    $self->_register_methods($dispatcher);

    $self->_set_dispatcher($dispatcher);

    return $self;
}

sub _register_methods{
    my $self = shift;
    my $dispatcher = shift;

    my $method = GRNOC::WebService::Method->new( name => 'get_users',
						 description => 'get a list of users',
						 callback => sub { return $self->get_users(@_); }
	);
    
    $method->add_input_parameter(
	required => 0,
	name => 'username',
	pattern => $GRNOC::WebService::Regex::NAME_ID,
	description => "username of the user");
    
    
    $method->add_input_parameter(
        required => 0,
        name => 'email',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "email of the user");


    $method->add_input_parameter(
        required => 0,
        name => 'fullname',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "fullname of the user");


    $method->add_input_parameter(
        required => 0,
        name => 'user_id',
        pattern => $GRNOC::WebService::Regex::NUMBER_ID,
        description => "user_id of the user to find");

    $dispatcher->register_method($method);

    

    $method = GRNOC::WebService::Method->new( name => 'add_user',
					      description => 'get a list of commands and the details of those commands',
					      callback => sub { return $self->add_user(@_); }
        );

    $method->add_input_parameter(
        required => 1,
        name => 'username',
        pattern => $GRNOC::WebService::Regex::NAME_ID,
        description => "username of the new user");

    $method->add_input_parameter(
	required => 0,
	name => 'email',
	pattern => $GRNOC::WebService::Regex::TEXT,
	description => "Email address of the new user");

    $method->add_input_parameter(
	required => 0,
	name => 'fullname',
	pattern => $GRNOC::WebService::Regex::TEXT,
	description => "Full Name of the new user");

    $dispatcher->register_method($method);
    
    $method = GRNOC::WebService::Method->new( name => 'modify_user',
                                              description => 'Modifies and existing user',
					      callback => sub { return $self->modify_user(@_); }
	);

    $method->add_input_parameter(
        required => 0,
        name => 'email',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Email address of the new user");

    $method->add_input_parameter(
        required => 0,
        name => 'fullname',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Full Name of the new user");

    $method->add_input_parameter( 
	required => 1,
	name => 'user_id',
	pattern => $GRNOC::WebService::Regex::NUMBER_ID,
	description => "User ID of the user to modify");

    $dispatcher->register_method($method);

    $method = GRNOC::WebService::Method->new( name => 'delete_user',
                                              description => 'deletes and existing user',
                                              callback => sub { return $self->delete_user(@_); }
        );

    $method->add_input_parameter(
        required => 1,
        name => 'user_id',
        pattern => $GRNOC::WebService::Regex::NUMBER_ID,
	description => "the id of the user to delete");

    $dispatcher->register_method($method);

}

=head2 get_users

=cut
sub get_users{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my %args;
    
    foreach my $key (keys (%{$p_ref})){
	$args{$key} = $p_ref->{$key}{'value'};
    }
    
    my $res = $self->db->get_users( %args );
    return {results => $res};
}

=head2 add_user

=cut
sub add_user{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $username = $p_ref->{'username'}{'value'};
    my $email = $p_ref->{'email'}{'value'};
    my $fullname = $p_ref->{'fullname'}{'value'};

    my $res = $self->db->add_user( $username, $email, $fullname);
    return {results => [{id => $res}]};
}

=head2 modify_user

=cut
sub modify_user{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;

    my $user_id = $p_ref->{'user_id'}{'value'};
    my $username = $p_ref->{'username'}{'value'};
    my $fullname = $p_ref->{'fullname'}{'value'};
    my $email = $p_ref->{'email'}{'value'};

    my $res = $self->db->modify_user(user_id => $user_id, 
				     username => $username,
				     fullname => $fullname,
				     email => $email);
    if ($res eq "0E0") {
        $m_ref->set_error("Update failed for user: $user_id");
        return;
    }
    return {results => [$res]};
}

=head2 delete_user

=cut
sub delete_user{
    my $self = shift;
    my $m_ref = shift;
    my $p_ref = shift;
    
    my $user_id = $p_ref->{'user_id'}{'value'};
    
    my $res = $self->db->delete_user( $user_id );

    if ($res eq "0E0") {
        $m_ref->set_error("Delete failed for user: $user_id");
        return;
    }
    return {results => [$res]};
}


=head2 handle_request

=cut
sub handle_request{
    my $self = shift;

    $self->dispatcher->handle_request();
}

1;
