#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Wiki::Confluence' ) || print "Bail out!\n";
}

diag( "Testing Wiki::Confluence $Wiki::Confluence::VERSION, Perl $], $^X" );
