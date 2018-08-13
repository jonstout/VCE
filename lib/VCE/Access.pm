#!/usr/bin/perl

## Copyright 2011 Trustees of Indiana University
##
##   Licensed under the Apache License, Version 2.0 (the "License");
##  you may not use this file except in compliance with the License.
##   You may obtain a copy of the License at
##
##       http://www.apache.org/licenses/LICENSE-2.0
##
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.
#

=head1 Package Access

    use VCE::Access;

Virtual Customer Equipment - Access module

=cut

package VCE::Access;

use strict;
use warnings;

use Moo;
use VCE;
use GRNOC::Log;
use Data::Dumper;
use VCE::Database::Connection;

has db => (is => 'rwp');
has config => (is => 'rwp');
has logger => (is => 'rwp');

=head2 BUILD

=over 4

=item db

=item config

=item logger

=back

=cut

sub BUILD{
    my ($self) = @_;

    my $logger = GRNOC::Log->get_logger("VCE::Access");
    $self->_set_logger($logger);

    $self->logger->info('Loading database: ' . $self->config);
    $self->_set_db(VCE::Database::Connection->new($self->config));

    return $self;
}

=head2 has_access

=cut
sub has_access{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'username'})){
        $self->logger->error("has_access: username not specified");
        return 0;
    }

    if(!defined($params{'workgroup'})){
        $self->logger->error("has_access: workgroup not specified");
        return 0;
    }

    if(!defined($params{'switch'})){
	$self->logger->error("has_access: switch not specified");
        return 0;
    }

    if(!defined($params{'port'})){
        $self->logger->error("has_access: port not specified");
        return 0;
    }

    return 0 if(!$self->user_in_workgroup( username => $params{'username'},
					   workgroup => $params{'workgroup'}));
    
    return 0 if(!$self->workgroup_has_access_to_port( workgroup => $params{'workgroup'},
                                                      switch => $params{'switch'},
                                                      port => $params{'port'},
                                                      vlan => $params{'vlan'}));
       
    $self->logger->debug("User " . $params{'username'} . " has access via workgroup " . $params{'workgroup'} . " has access to switch:port " . $params{'switch'} . ":" . $params{'port'});
    return 1;
}

=head2 workgroup_owns_port

    my $ok = workgroup_owns_port(
      workgroup => $string,
      switch    => $string,
      port      => $string
    );

=cut
sub workgroup_owns_port{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("workgroup_owns_port: workgroup not specified");
        return 0;
    }

    if(!defined($params{'switch'})){
        $self->logger->error("workgroup_owns_port: switch not specified");
        return 0;
    }

    if(!defined($params{'port'})){
        $self->logger->error("workgroup_owns_port: port not specified");
        return 0;
    }

    my $workgroup = $self->db->get_workgroups(name => $params{workgroup})->[0];
    if (!defined $workgroup) {
        return 0;
    }
    my $switch = $self->db->get_switches(name => $params{switch})->[0];
    if (!defined $switch) {
        return 0;
    }
    my $intf = $self->db->get_interfaces(
        workgroup_id => $workgroup->{id},
        switch_id => $switch->{id},
        name => $params{port}
    );
    if (!$intf || @$intf == 0) {
        return 0;
    }
    return 1;
}


=head2 workgroups_owned_ports

=cut
sub workgroups_owned_ports{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("workgroups_owned_ports: workgroup not specified");
        return;
    }

    my @owned_ints;

    my $workgroup = $self->db->get_workgroups(name => $params{workgroup})->[0];
    if (!defined $workgroup) {
        return [];
    }

    my $interfaces = $self->db->get_interfaces(workgroup_id => $workgroup->{id});
    foreach my $intf (@$interfaces) {
        my $switch = $self->db->get_switch($intf->{switch_id});
        push @owned_ints, { switch => $switch->{name}, port => $intf->{name} };
    }

    return \@owned_ints;
}

=head2 user_in_workgroup

=cut
sub user_in_workgroup{
    my $self = shift;
    my %params = @_;

    if (!defined $params{username}) {
        $self->logger->error("user_in_workgroup: username not specified");
        return 0;
    }

    if (!defined $params{workgroup}) {
        $self->logger->error("user_in_workgroup: workgroup not specified");
        return 0;
    }

    my $user = $self->db->get_user_by_name($params{username});
    if (!defined $user) {
        $self->logger->error("User $params{username} does not exist");
        return 0;
    }

    foreach my $workgroup (@{$user->{workgroups}}) {
        if ($workgroup->{name} eq $params{'workgroup'}) {
            $self->logger->debug("$params{'username'} is in workgroup $params{'workgroup'}");
            return 1;
        }
    }

    $self->logger->debug("$params{'username'} is not in workgroup $params{'workgroup'}");
    return 0;
}

=head2 workgroup_has_access_to_port

    my $ok = workgroup_has_access_to_port(
      workgroup => $string,
      switch    => $string,
      port      => $string,
      vlan      => $string  (optional)
    );

workgroup_has_access_to_port determines if the C<workgroup> has access
to the C<(switch, port, vlan)> 3-tuple as defined in the config.

If C<vlan> is not provided this method checks that the workgroup has
access to at least one VLAN on C<(switch, port)>.

=cut
sub workgroup_has_access_to_port{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("workgroup_has_access_to_port: workgroup not specified");
        return 0;
    }

    if(!defined($params{'switch'})){
        $self->logger->error("workgroup_has_access_to_port: switch not specified");
        return 0;
    }

    if(!defined($params{'port'})){
        $self->logger->error("workgroup_has_access_to_port: port not specified");
        return 0;
    }

    my $workgroup = $self->db->get_workgroup(name => $params{workgroup});
    my $acls = $self->db->get_workgroup_interfaces($workgroup->{id});
    foreach my $acl (@$acls) {
        if ($acl->{switch_name} ne $params{switch} || $acl->{name} ne $params{port}) {
            next;
        }

        if (!defined $params{vlan}) {
            return 1;
        }

        if ($acl->{high} >= $params{vlan} && $acl->{low} <= $params{vlan}) {
            return 1;
        }
    }

    return 0;
}

=head2 get_tags_on_port

    my $tags = get_tags_on_port(
      workgroup => $string,
      switch    => $string,
      port      => $string
    );

get_tags_on_ports returns an array of the VLAN tags that C<workgroup>
may create on C<switch>'s C<port>. If C<workgroup> is the admin
workgroup, the resulting array will include all VLAN tags.

=cut
sub get_tags_on_port{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("get_tags_on_port: workgroup not specified");
        return;
    }

    if(!defined($params{'switch'})){
        $self->logger->error("get_tags_on_port: switch not specified");
        return;
    }

    if(!defined($params{'port'})){
        $self->logger->error("get_tags_on_port: port not specified");
        return;
    }

    my $workgroup = $self->db->get_workgroup(name => $params{workgroup});
    my $acls = $self->db->get_workgroup_interfaces($workgroup->{id});

    # TODO
    # Account for admin workgroup
    # my $is_admin = $self->get_admin_workgroup()->{name} eq $params{workgroup} ? 1 : 0;
    my $result = {};
    foreach my $acl (@$acls) {
        if ($acl->{switch_name} ne $params{switch} || $acl->{name} ne $params{port}) {
            next;
        }

        if ($acl->{workgroup_id} != $workgroup->{id}) {
            # Filters out acls results based on port owners
            next;
        }
        # if ($acl->{workgroup_id} eq $workgroup->{id}) {
        #     for (my $i = 1; $i < 4095; $i++) {
        #         $result->{$i} = 1;
        #     }
        #     my @r = keys $result;
        #     return \@r;
        # }

        for (my $i = $acl->{low}; $i <= $acl->{high}; $i++) {
            $result->{$i} = 1;
        }
    }

    my @r = keys $result;
    return \@r;
}


=head2 friendly_display_vlans

friendly_display_vlans takes an arrary of vlans and returns a list of
human readable vlan ranges. An example range looks like `100-200`, and
will always be of form `low-high`.

=cut
sub friendly_display_vlans{
    my $self = shift;
    my $vlans = shift;

    my @f_vlans;
    my $first;
    my $last;

    # The work below expects a sorted array of vlans
    my @sorted_vlans = sort { $a <=> $b } @{$vlans};

    foreach my $vlan (@sorted_vlans) {
        if(!defined($first)){
            $first = $vlan;
            $last = $vlan;
        }else{
            if($last + 1 == $vlan){
                $last = $vlan;
            }else{
                if($last == $first){
                    push(@f_vlans, $first);
                    $first = $vlan;
                    $last = $vlan;
                }else{
                    push(@f_vlans, $first . "-" . $last);
                    $first = $vlan;
                    $last = $vlan;                
                }
            }
        }
    }

    if (!defined $first && !defined $last) {
        return [];
    }

    #do the last push
    if($first == $last){
        push(@f_vlans, $first);
    }else{
        push(@f_vlans, $first . "-" . $last);
    }
    return \@f_vlans;
}

=head2 get_workgroup_switches

=cut
sub get_workgroup_switches{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("get_workgroup_switches: workgroup not specified");
        return;
    }
    my $result = [];

    my $workgroup = $self->db->get_workgroup(name => $params{workgroup});
    if (!defined $workgroup) {
        return $result;
    }
    my $switches = $self->db->get_switches(workgroup_id => $workgroup->{id});

    foreach my $switch (@$switches) {
        push @$result, $switch->{name};
    }
    return $result;
}

=head2 get_workgroup_users

=cut
sub get_workgroup_users{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("get_workgroup_switches: workgroup not specified");
        return;
    }

    if(defined($self->config->{'workgroups'}->{$params{'workgroup'}})){
        my @users = keys (%{$self->config->{'workgroups'}->{$params{'workgroup'}}->{'user'}});
        return \@users;
    }

    return;


}

=head2 get_workgroup_description

=cut
sub get_workgroup_description{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'workgroup'})){
        $self->logger->error("get_workgroup_description: workgroup not specified");
        return;
    }

    if(defined($self->config->{'workgroups'}->{$params{'workgroup'}})){
        return $self->config->{'workgroups'}->{$params{'workgroup'}}->{'description'};
    }

    return;
}


=head2 get_switch_description

=cut
sub get_switch_description{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'switch'})){
        $self->logger->error("get_switch_description: workgroup not specified");
        return;
    }

    my $switch = $self->db->get_switches(name => $params{switch})->[0];
    if (!defined $switch) {
        return;
    }

    return $switch->{description};


    if(defined($self->config->{'switches'}->{$params{'switch'}})){
        return $self->config->{'switches'}->{$params{'switch'}}->{'description'};
    }

    return;

}

=head2 get_switch_commands

=cut
sub get_switch_commands{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'switch'})){
        $self->logger->error("get_switch_commands: switch not specified");
        return;
    }

    return $self->config->{'switches'}{$params{'switch'}}->{'commands'}{'system'};

}

=head2 get_port_commands

=cut
sub get_port_commands{

    my $self = shift;
    my %params = @_;

    if(!defined($params{'switch'})){
        $self->logger->error("get_port_commands: switch not specified");
        return;
    }

    return $self->config->{'switches'}{$params{'switch'}}->{'commands'}->{'port'};
}

=head2 get_vlan_commands

=cut
sub get_vlan_commands{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'switch'})){
        $self->logger->error("get_vlan_commands: switch not specified");
        return;
    }

    return $self->config->{'switches'}{$params{'switch'}}->{'commands'}->{'vlan'};
}

=head2 get_switch_ports

=cut
sub get_switch_ports{
    my $self = shift;
    my %params = @_;

    if(!defined($params{'switch'})){
        $self->logger->error("get_switch_description: workgroup not specified");
        return;
    }

    if(!defined($params{'workgroup'})){
        $self->logger->error("get_workgroup_switches: workgroup not specified");
        return;
    }

    my $workgroup = $self->db->get_workgroup(name => $params{workgroup});
    my $acls = $self->db->get_workgroup_interfaces($workgroup->{id});

    my $ports = {};
    foreach my $acl (@$acls) {
        if ($acl->{switch_name} ne $params{switch}) {
            next;
        }

        if ($acl->{workgroup_id} eq $workgroup->{id}) {
            $ports->{$acl->{name}} = 1;
            next;
        }

        if ($acl->{high} >= $params{vlan} && $acl->{low} <= $params{vlan}) {
            $ports->{$acl->{name}} = 1;
            next;
        }
    }

    my @result = keys %$ports;
    return \@result;
}

=head2 get_switches

=cut
sub get_switches{
    my $self = shift;

    my @switches;
    foreach my $s (keys %{$self->config->{'switches'}}){
        push(@switches, $self->config->{'switches'}->{$s});
    }

    return \@switches;

}

=head2 get_admin_workgroup

=cut
sub get_admin_workgroup {
    my $self = shift;

    my $workgroup = $self->db->get_workgroups(name => 'admin')->[0];
    return $workgroup;
}

=head2 is_port_owner

    my ($ok, $error) = is_port_owner($workgroup, $switch, $port);

is_port_owner returns 1 if C<$workgroup> owns C<($switch, $port)>. An
error string describing the authorization failure is returned on
failure.

=cut
sub is_port_owner {
    my $self      = shift;
    my $workgroup = shift;
    my $switch    = shift;
    my $port      = shift;

    my $wg = $self->db->get_workgroups(name => $workgroup)->[0];
    if (!defined $wg) {
        return (0, "Couldn't find a workgroup named $workgroup.");
    }

    my $sw = $self->db->get_switches(name => $switch)->[0];
    if (!defined $sw) {
        return (0, "Couldn't find a switch named $switch.");
    }

    my $interface = $self->db->get_interfaces(
        workgroup_id => $wg->{id},
        switch_id => $sw->{id},
        name => $port
    )->[0];
    if (!defined $interface) {
        return (0, "Workgroup $workgroup doesn't own $port on $switch.");
    }

    return (1, undef);
}

=head2 is_vlan_permittee

    my ($ok, $error) = is_vlan_permittee(
      $workgroup, # string
      $swich,     # string
      $ports,     # []string
      $vlan       # integer
    );

is_vlan_permittee returns 1 if C<$workgroup> has the right to
provision C<$vlan> on all C<$ports> on C<$switch>. The admin workgroup
will allways get granted permission. An error string describing the
authorization failure is returned on failure.

=cut
sub is_vlan_permittee {
    my $self      = shift;
    my $workgroup = shift;
    my $switch    = shift;
    my $ports     = shift;
    my $vlan      = shift;

    my $count = @{$ports};
    if ($count < 1) {
        $self->logger->warn("Checking VLAN permissions on zero endpoints.");
    }

    my $is_admin = $self->get_admin_workgroup()->{name} eq $workgroup ? 1 : 0;
    if ($is_admin) {
        return (1, undef);
    }

    foreach my $port (@{$ports}) {
        if (!defined $self->config->{switches}->{$switch}) {
            return (0, "Couldn't find a switch named $switch.");
        }

        if (!defined $self->config->{switches}->{$switch}->{ports}->{$port}) {
            return (0, "Couldn't find a port named $port on $switch.");
        }

        my $port_config = $self->config->{switches}->{$switch}->{ports}->{$port};

        if (!defined $port_config->{tags}->{$vlan}) {
            return (0, "No port on switch $switch named $port with VLAN $vlan found in configuration.");
        }

        if ($port_config->{'tags'}->{$vlan} ne $workgroup) {
            return (0, "Workgroup $workgroup does not have access to VLAN $vlan on port $port on $switch.");
        }
    }

    return (1, undef);
}

=head2 get_visible_vlans

    my $vlans = get_visible_vlans(
      workgroup => 'admin',
      swich     => 'mlxe16-2.sdn-test.grnoc.iu.edu'
    );

get_visible_vlans returns a hash of all VLANs C<workgroup> is
authorized to view on C<switch>. This should not be used to determine
what VLANs C<workgroup> may provision. The admin workgroup will return
a hash containing all known tags.

Returns

    {
      100 => 1,
      300 => 1
    }

=cut
sub get_visible_vlans {
    my $self      = shift;
    my %params = @_;

    my $workgroup = $params{workgroup};
    my $switch    = $params{switch};

    my $workgroup = $self->db->get_workgroup(name => $params{workgroup});
    my $acls = $self->db->get_workgroup_interfaces($workgroup->{id});

    my $result = {};

    my $is_admin = $self->get_admin_workgroup()->{name} eq $params{workgroup} ? 1 : 0;
    if ($is_admin) {
        for (my $i = 1; $i < 4095; $i++) {
            $result->{$i} = 1;
        }
        my @r = keys $result;
        return \@r;

    }

    foreach my $acl (@$acls) {
        if ($acl->{switch_name} ne $params{switch} || $acl->{name} ne $params{port}) {
            next;
        }

        for (my $i = $acl->{low}; $i <= $acl->{high}; $i++) {
            $result->{$i} = 1;
        }
    }

    return $result;
}

1;
