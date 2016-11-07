use strict;
use warnings;
use ExtUtils::MakeMaker;

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
