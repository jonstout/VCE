use strict;
use warnings;
use ExtUtils::MakeMaker;

use Apache::TestMM qw(test clean);
use Apache::TestRunPerl ();
use FindBin;

sub MY::postamble { << 'END'; }
rpm:    dist
	rpmbuild -ta vce-$(VERSION).tar.gz

TEST_VERBOSE=1
test_jenkins : pure_all
	$(FULLPERL) t/TEST $(TEST_VERBOSE)
END
# test_jenkins :
# 	PERL5OPT=-MDevel::Cover=-db,$FindBin::Bin/cover_db make test PERL_TEST_HARNESS_DUMP_TAP=$FindBin::Bin/tap/

WriteMakefile(
    NAME                => 'vce',
    AUTHOR              => 'GRNOC Systems Engineering <syseng@grnoc.iu.edu>',
    VERSION_FROM        => 'lib/VCE.pm',
    PL_FILES            => {},
    PREREQ_PM => {
    'Net::SSH2' => 0
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'vce-*' },
    );

push(@ARGV, '-apxs', '/usr/sbin/apxs');
push(@ARGV, '-documentroot', "$FindBin::Bin/www/services/");
push(@ARGV, '-maxclients', 4);


Apache::TestMM::filter_args();
Apache::TestRunPerl->generate_script();
