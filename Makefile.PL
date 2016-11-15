use strict;
use warnings;
use ExtUtils::MakeMaker;

use Apache::TestMM qw(test clean);
use Apache::TestRunPerl ();
use FindBin;

sub MY::postamble { <<"END"; }

test_jenkins :
	PERL5OPT=-MDevel::Cover=-db,$FindBin::Bin/cover_db make test PERL_TEST_HARNESS_DUMP_TAP=$FindBin::Bin/tap/

END

WriteMakefile(
    NAME                => 'perl-VCE',
    AUTHOR              => 'GRNOC Systems Engineering <syseng@grnoc.iu.edu>',
    VERSION_FROM        => 'lib/VCE.pm',
    PL_FILES            => {},
    PREREQ_PM => {
    'Net::SSH2' => 0
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'perl-VCE-*' },
    );

push(@ARGV, '-apxs', '/usr/sbin/apxs');
push(@ARGV, '-documentroot', "$FindBin::Bin/www/services/");
push(@ARGV, '-maxclients', 4);

Apache::TestMM::filter_args();
Apache::TestRunPerl->generate_script();
