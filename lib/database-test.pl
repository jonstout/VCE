#!/usr/bin/perl
use strict;
use warnings;

use Data::Dumper;
use GRNOC::Config;

use VCE::Database::Connection;
use VCE::NetworkDB;

`rm delme.db`;
`sqlite3 delme.db < etc/schema.sqlite`;

my $db = VCE::Database::Connection->new("delme.db");

my $switch_id = 1;
my $workgroup_id = 1;
my $interface_id = 1;

my $config_file = "/etc/vce/access_policy.xml";

my $conf = _process_config();

# Load workgroups
my $workgroups = $conf->{workgroups};
# warn Dumper($workgroups);

foreach my $key (keys %$workgroups) {
    my $wg = $workgroups->{$key};
    my $r = $db->add_workgroup($wg->{name}, $wg->{description});
    warn "$r";
}

my $db_workgroups = $db->get_workgroups();
# print "Workgroups:\n";
# warn Dumper($db_workgroups);

my $wg2id = {};
foreach my $wg (@$db_workgroups) {
    $wg2id->{$wg->{name}} = $wg->{id};
}
warn Dumper($wg2id);

my $users = $conf->{users};
# warn Dumper($users);

foreach my $key (keys %$users) {
    my $u = $users->{$key};
    my $u_id = $db->add_user($key, '', '');

    foreach my $wg (@$u) {
        my $w = $db->get_workgroup(name => $wg);
        my $u_wg_id = $db->add_user_to_workgroup($u_id, $w->{id}, 'admin');
    }
}

my $db_users = $db->get_users();
# print "Users:\n";
# warn Dumper($db_users);

my $user2id = {};
foreach my $user (@$db_users) {
    $user2id->{$user->{username}} = $user->{id};
}
warn Dumper($user2id);

my $user = $db->get_user(4);
# print "User:\n";
# warn Dumper($user);

my $switches = $conf->{switches};
# warn Dumper($switches);

my $sw2id = {};
my $intf2id = {};

foreach my $key (keys %$switches) {
    my $sw = $switches->{$key};
    my $sw_id = $db->add_switch(
        $sw->{name},
        $sw->{description},
        $sw->{ip},
        $sw->{ssh_port},
        830,
        $sw->{vendor},
        $sw->{model},
        $sw->{version}
    );

    $sw2id->{$sw->{name}} = $sw_id;

    foreach my $pname (keys %$sw->{ports}) {
        my $p = $sw->{ports}->{$pname};
        my $w = $db->get_workgroup(name => $p->{owner});
        my $intf_id = $db->add_interface(
            name => $pname,
            description => $p->{description},
            switch_id => $sw_id,
            workgroup_id => $w->{id}
        );
        $intf2id->{$sw->{name}}->{$pname} = $intf_id;

        foreach my $acl (@{$p->{tags}}) {
            my $w2 = $db->get_workgroup(name => $acl->{workgroup});
            $db->add_acl($intf_id, $w2->{id}, $acl->{start}, $acl->{end});
        }
    }

    my $port_commands = $sw->{commands}->{port};
    foreach my $cmd (@$port_commands) {
        my $cmd_id = $db->add_command($cmd->{name}, $cmd->{description}, 'interface', $cmd->{actual_command});

        foreach my $name (keys %{$cmd->{params}}) {
            my $type = $cmd->{params}->{$name}->{type} eq 'select' ? 'option' : 'input';
            $db->add_parameter(
                $cmd_id,
                $name,
                $cmd->{params}->{$name}->{description},
                $cmd->{params}->{$name}->{pattern},
                $type
            );
        }
        $db->add_command_to_switch($cmd_id, $sw_id, $cmd->{user_type});
    }
    $port_commands = $sw->{commands}->{system};
    foreach my $cmd (@$port_commands) {
        my $cmd_id = $db->add_command($cmd->{name}, $cmd->{description}, 'switch', $cmd->{actual_command});

        foreach my $name (keys %{$cmd->{params}}) {
            my $type = $cmd->{params}->{$name}->{type} eq 'select' ? 'option' : 'input';
            $db->add_parameter(
                $cmd_id,
                $name,
                $cmd->{params}->{$name}->{description},
                $cmd->{params}->{$name}->{pattern},
                $type
            );
        }
        $db->add_command_to_switch($cmd_id, $sw_id, $cmd->{user_type});
    }
    $port_commands = $sw->{commands}->{vlan};
    foreach my $cmd (@$port_commands) {
        my $cmd_id = $db->add_command($cmd->{name}, $cmd->{description}, 'vlan', $cmd->{actual_command});

        foreach my $name (keys %{$cmd->{params}}) {
            my $type = $cmd->{params}->{$name}->{type} eq 'select' ? 'option' : 'input';
            $db->add_parameter(
                $cmd_id,
                $name,
                $cmd->{params}->{$name}->{description},
                $cmd->{params}->{$name}->{pattern},
                $type
            );
        }
        $db->add_command_to_switch($cmd_id, $sw_id, $cmd->{user_type});
    }
}

my $db_switches = $db->get_switches();
# warn Dumper($db_switches);

my $db_sw = $db->get_switch(1);
# warn Dumper($db_sw);

my $db_intfs = $db->get_interfaces();
# warn Dumper($db_intfs);

my $db_acls = $db->get_acls(6, 3);
# warn Dumper($db_acls);

my $db_cmds = $db->get_commands();
# warn Dumper($db_cmds);
# warn Dumper($conf);

# ===

my $old_db = VCE::NetworkDB->new(path => '/var/lib/vce/network_model.sqlite');

my $old_intfs = $old_db->get_interfaces();
foreach my $ointf (@{$old_intfs}) {
    my $id = $intf2id->{$ointf->{switch}}->{$ointf->{name}};
    if (defined $id) {
        $db->update_interface(
            id => $id,
            admin_up => $ointf->{admin_status},
            description => $ointf->{description},
            hardware_type => $ointf->{hardware_type},
            link_up => $ointf->{status},
            mac_addr => $ointf->{mac_addr},
            mtu => $ointf->{mtu},
            speed => $ointf->{speed}
        );
    } else {
        my $nid = $db->add_interface(
            switch_id => $sw2id->{$ointf->{switch}},
            admin_up => $ointf->{admin_status},
            description => $ointf->{description},
            hardware_type => $ointf->{hardware_type},
            link_up => $ointf->{status},
            mac_addr => $ointf->{mac_addr},
            mtu => $ointf->{mtu},
            speed => $ointf->{speed},
            name => $ointf->{name}
        );
        $intf2id->{$ointf->{switch}}->{$ointf->{name}} = $nid;
    }
}

print "Interfaces:\n";
warn Dumper($intf2id);

my $old_vlans = $old_db->get_vlans_state();

foreach my $old_vlan (@{$old_vlans}) {
    my $vlan_id = $db->add_vlan(
        name => $old_vlan->{description},
        number => $old_vlan->{vlan},
        description => $old_vlan->{description},
        created_by => $user2id->{$old_vlan->{username}},
        workgroup_id => $wg2id->{$old_vlan->{workgroup}},
        created_on => $old_vlan->{create_time}
    );

    my $sw = $old_vlan->{switch};
    my $tag = $old_vlan->{vlan};

    foreach my $ep (@{$old_vlan->{endpoints}}) {
        $db->add_tag('tagged', $intf2id->{$sw}->{$ep->{port}}, $vlan_id);
    }
}

my $nvlans = $db->get_vlans();
foreach my $v (@{$nvlans}) {
    $v->{endpoints} = $db->get_tags(vlan_id => $v->{id});
}
warn Dumper($nvlans);


sub _process_config{

    my $config = GRNOC::Config->new(
        config_file => $config_file,
        force_array => 1,
        schema => '/etc/vce/config.xsd'
    );

    if ($config->validate() != 1) {
        my $err = $config->get_error()->{'backtrace'}->{'message'};
        exit 1;
    }

    my %workgroups;
    my %users;

    my $wgs = $config->get('/accessPolicy/workgroup');
    foreach my $workgroup (@$wgs){

        my $grp = {};
        $grp->{'name'} = $workgroup->{'name'};
        $grp->{'admin'} = $workgroup->{'admin'};
        $grp->{'description'} = $workgroup->{'description'};
        $grp->{'user'} = $workgroup->{'user'};
        $workgroups{$grp->{'name'}} = $grp;
        foreach my $user (keys(%{$grp->{'user'}})){
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

        my $s = {};
        $s->{'name'} = $switch->{'name'};
        $s->{'description'} = $switch->{'description'};
        $s->{'ssh_port'} = $switch->{'ssh_port'};
        $s->{'vendor'} = $switch->{'vendor'};
        $s->{'model'} = $switch->{'model'};
        $s->{'version'} = $switch->{'version'};
        $s->{'ip'} = $switch->{'ip'};

        $s->{'commands'} = _process_command_config($switch->{'commands'}->[0]);

        my %ports;
        foreach my $port (keys(%{$switch->{'port'}})){
            my $p = {};
            my %tags;

            foreach my $tag (@{$switch->{'port'}->{$port}->{'tags'}}){
                for(my $i=$tag->{'start'};$i<=$tag->{'end'};$i++){
                    $tags{$i} = $tag->{'workgroup'};
                }
            }

            $p->{'tags'} = $switch->{'port'}->{$port}->{'tags'}; #\%tags;
            $s->{'ports'}->{$port} = $p;
            $p->{'owner'} = $switch->{'port'}->{$port}->{'owner'};
            $p->{'description'} = $switch->{'port'}->{$port}->{'description'};
        }

        $switches{$switch->{'name'}} = $s;
    }

    $cfg->{'switches'} = \%switches;
    return $cfg;
}

=head2 _process_command_config

=cut

sub _process_command_config{
    my $config = shift;

    my $cfg = {};

    foreach my $type ("system","port","vlan"){
        my %commands = %{$config->{$type}->[0]->{'command'}};
        foreach my $cmd (keys(%commands)){
            my $val = {
                name => $cmd,
                method_name => $commands{$cmd}{'method_name'},
                interaction => $commands{$cmd}{'interaction'},
                actual_command => $commands{$cmd}{'cmd'}->[0],
                type => $commands{$cmd}{'type'},
                configure => $commands{$cmd}{'configure'},
                params => $commands{$cmd}{'parameter'},
                description => $commands{$cmd}{'description'},
                context => $commands{$cmd}{'context'},
                user_type => $commands{$cmd}{'user_type'} || 'admin'
            };
            if(!defined($val->{'configure'})){
                delete $val->{'configure'};
            }

            if(!defined($val->{'context'})){
                delete $val->{'context'};
            }

            push(@{$cfg->{$type}},$val);
        }
    }

    return $cfg;
}
