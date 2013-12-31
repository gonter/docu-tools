#!/usr/bin/perl

=head1 NAME

  s1.pl

=head1 DESCRIPTION

Script to play with Tomboy::Note::Simple for testing.

=cut

use strict;

use lib 'lib';

use Tomboy::Note::Simple;

use Data::Dumper;
$Data::Dumper::Indent= 1;

die "no note filename specified" unless (@ARGV);

open (FO, '>:utf8', 'do_verify.sh');
while (my $arg= shift (@ARGV))
{
  process_note ($arg);
}
close (FO);

exit (0);

sub process_note
{
  my $note_fnm= shift;

print '='x90, "\n";
print "process_note note_fnm=[$note_fnm]\n";

# V1:
my $n= parse Tomboy::Note::Simple ($note_fnm);

# V2:
# my $n= new Tomboy::Note::Simple; $n->parse ($note_fnm);

$n->text_to_lines ();
# print "lines: ", Dumper ($n->{'lines'});
$n->parse_lines ();
# print "n: ", Dumper ($n);

my $saved= $n->save();

print "saved=[$saved]\n";
my @cmd= ('diff', '-u', $note_fnm, $saved);
print join (' ', @cmd), "\n";
my $rc= system (@cmd);
print "rc=[$rc]\n\n";

if ($rc != 0)
{
  print FO join (' ', @cmd), "\n";
}

  $rc;
}


