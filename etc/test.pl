use strict;
use warnings;

use Data::Dumper;
use GRNOC::Config;

my $c = new GRNOC::Config(config_file => './etc/access_policy.xml', schema => './etc/config.xsd', debug => 1);

warn $c->validate();
warn $c->get_error()->{'backtrace'}->{'message'};
