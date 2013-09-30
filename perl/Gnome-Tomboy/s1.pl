#!/usr/bin/perl

use strict;

use lib 'lib';

use Tomboy::Note::Simple;

use Data::Dumper;
$Data::Dumper::Indent= 1;

my $note_fnm= shift (@ARGV);

die "no note filename specified" unless ($note_fnm);

# V1:
# my $n= parse Tomboy::Note::Simple ($note_fnm);

# V2:
my $n= new Tomboy::Note::Simple; $n->parse ($note_fnm);

print "n: ", Dumper ($n);

exit (0);

