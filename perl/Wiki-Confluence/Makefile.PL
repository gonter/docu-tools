use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Wiki::Confluence',
    AUTHOR              => q{Gerhard Gonter <ggonter@cpan.org>},
    VERSION_FROM        => 'lib/Wiki/Confluence.pm',
    ABSTRACT_FROM       => 'lib/Wiki/Confluence.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Wiki-Confluence-*' },
);
