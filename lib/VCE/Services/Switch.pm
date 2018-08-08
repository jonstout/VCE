
#!/usr/bin/perl

package VCE::Services::Switch;

use strict;
use warnings;

use Moo;
use GRNOC::Log;
use GRNOC::RabbitMQ::Client;
use GRNOC::WebService::Dispatcher;
use GRNOC::WebService::Method;
use GRNOC::WebService::Regex;

use VCE::Access;
use VCE::Database::Connection;
use Template;

has vce => (is => 'rwp');
has logger => (is => 'rwp');
has rabbit_client => (is => 'rwp');
has dispatcher => (is => 'rwp');
has rabbit_mq => (is => 'rwp');
has template => (is => 'rwp');

=head2 BUILD

=over 4

=item access

=item dispatcher

=item logger

=item rabbit_client

=item rabbit_mq

=item template

=item vce

=back

=cut

sub BUILD{
    my ($self) = @_;
    my $logger = GRNOC::Log->new(config => '/etc/vce/logging.conf', watch => 15);
    my $log    = $logger->get_logger("VCE::Services::Switch");
    $self->_set_logger($log);


    $self->_set_vce( VCE->new() );

    my $client = GRNOC::RabbitMQ::Client->new(
        user     => $self->rabbit_mq->{'user'},
        pass     => $self->rabbit_mq->{'pass'},
        host     => $self->rabbit_mq->{'host'},
        timeout  => 30,
        port     => $self->rabbit_mq->{'port'},
        exchange => 'VCE',
        topic    => 'VCE.Switch.'
    );
    $self->_set_rabbit_client($client);

    my $dispatcher = GRNOC::WebService::Dispatcher->new();

    $self->_set_template(Template->new());

    $self->_register_switch_functions($dispatcher);

    $self->_set_dispatcher($dispatcher);

    return $self;
}

sub _register_switch_functions {
    my $self = shift;
    my $d = shift;
    # name="mlxel-2.sdn-test.grnoc.iu.edu"
    # ip="156.56.6.221"
    # description="na"
    # ssh_port="22"
    # vendor="Brocade"
    # model="MLXe"
    # version="5.8.0"
    my $method = GRNOC::WebService::Method->new( name => "add_switch",
        description => "Method for adding a switch",
        callback => sub {
            return $self->_add_switch(@_)
        });

    $method->add_input_parameter( required => 1,
        name => 'name',
        pattern => $GRNOC::WebService::Regex::NAME_ID,
        description => "Name of the switch to be added" );


    $method->add_input_parameter( required => 1,
        name => 'ip',
        pattern => $GRNOC::WebService::Regex::IP_ADDRESS,
        description => "IP address of switch" );


    $method->add_input_parameter( required => 0,
        name => "description",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "switch description");


    $method->add_input_parameter( required => 1,
        name => 'ssh',
        pattern => $GRNOC::WebService::Regex::INTEGER,
        description => "ssh port for the switch" );


    $method->add_input_parameter( required => 1,
        name => "vendor",
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "Switch vendor");


    $method->add_input_parameter( required => 1,
        name => 'model',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "switch model" );

    $method->add_input_parameter( required => 1,
        name => 'version',
        pattern => $GRNOC::WebService::Regex::TEXT,
        description => "switch version" );

    eval {
        $d->register_method($method);
    };
    undef $method;

    $method = GRNOC::WebService::Method->new( name => "modify_switch",
        description => "Method for modifying a switch",
        callback => sub {
            return $self->_modify_switch(@_)
        });
    eval {
        $d->register_method($method);
    };
    undef $method;

    $method = GRNOC::WebService::Method->new( name => "delete_switch",
        description => "Method for deleting a switch",
        callback => sub {
            return $self->_delete_switch(@_)
        });
    eval {
        $d->register_method($method);
    };
    undef $method;

}


=head2 handle_request

=cut

sub handle_request{
    my $self = shift;
    $self->dispatcher->handle_request();
}



sub _add_switch {

    my $result;
    my $result1;
    warn Dumper("IN ADD SWITCH");
    my $self = shift;
    my $params = shift;
    # warn Dumper($self);
    # warn Dumper($params->{'input_params'});
    # warn Dumper($params);
    my $db = VCE::Database::Connection->new("/var/lib/vce/database.sqlite");
    $result = $db->add_switch( $params->{'input_params'}{'name'}{'value'},
        $params->{'input_params'}{'description'}{'value'},
        $params->{'input_params'}{'ip'}{'value'},
        $params->{'input_params'}{'ssh_port'}{'value'},
        # $params->{'input_params'}{''}{'value'}, #netconf
        830, # change
        $params->{'input_params'}{'vendor'}{'value'},
        $params->{'input_params'}{'model'}{'value'},
        $params->{'input_params'}{'version'}{'value'},
    );
    warn Dumper($result);
    return $result1;
}


sub _modify_switch {
    my $result;
    warn Dumper("IN MODIFY SWITCH");
    return $result;
}

sub _delete_switch {
    my $result;
    warn Dumper("IN DELETE SWITCH");
    return $result;
}

1;
