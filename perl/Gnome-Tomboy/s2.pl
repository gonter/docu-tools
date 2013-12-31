#!/usr/bin/perl

=head1 NAME

  s2.pl

=head1 DESCRIPTION

Script to play with Tomboy::Directory for testing.

Generates a CSV file as TOC (table of contents) which might be useful.

=cut

use strict;

use lib 'lib';

use Util::Simple_CSV;
use Data::Dumper;
$Data::Dumper::Indent= 1;

# use Tomboy::Note::Simple;
use Tomboy::Directory;

my $note_dir= shift (@ARGV);
my $toc_file= 'Tomboy-TOC.csv';

die "no note dir specified" unless ($note_dir);

$note_dir=~ s#/+$##;
my $tb_d= new Tomboy::Directory ('dir' => $note_dir);

print "tb_d: ", Dumper ($tb_d);

my $toc_data= $tb_d->scan_dir ($note_dir);
# TODO: if verbose or so print "toc_data: ", Dumper ($toc_data);

my $toc= new Util::Simple_CSV ('UTF8' => 1, 'no_hash' => 1);
$toc->define_columns (Tomboy::Directory::TB_attrs());
$toc->{'data'}= $toc_data;
$toc->save_csv_file ('filename' => $toc_file, 'separator' => "\t", 'UTF8' => 1);

exit (0);

