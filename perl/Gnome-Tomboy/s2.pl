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

my $toc_file= 'Tomboy-TOC.csv';

my @PAR= ();
while (my $arg= shift (@ARGV))
{
  if ($arg =~ /^-/)
  {
    usage();
  }
  else
  {
    push (@PAR, $arg);
  }
}

my $note_dir= shift (@PAR);
die "no note dir specified" unless ($note_dir);

$note_dir=~ s#/+$##;
my $tb_d= new Tomboy::Directory ();
print "tb_d: ", Dumper ($tb_d);

my $toc= new Util::Simple_CSV ('UTF8' => 1, 'no_array' => 1, 'separator' => "\t", 'UTF8' => 1);

my $mode= 0;
my $rows= [];

if (-f $toc_file)
{
  $toc->load_csv_file ($toc_file);

  $mode= 1;
  $rows= $toc->{'data'};
  print "preparing quick scan, loaded [$toc_file]\n";
  # print "toc: ", Dumper ($toc);
  # print "rows: ", Dumper ($rows);
  # exit;
}
else
{
  # $toc->define_columns (Tomboy::Directory::TB_attrs());
  $toc->define_columns ($tb_d->TB_attrs());
}

my $toc_data= $tb_d->scan_dir ($note_dir, $rows, $mode);
# TODO: if verbose or so print "toc_data: ", Dumper ($toc_data);

$toc->{'data'}= $toc_data;
# TODO: optionally sort the returned values
$toc->sort ('uuid');
# print "toc: ", Dumper ($toc);
$toc->save_csv_file ('filename' => $toc_file, 'separator' => "\t", 'UTF8' => 1);

exit (0);

__END__

=head1 TODO

 * enhance this to create a standalone script (e.g. tbshow)
 * cache the data in ~/.gcache ?? check out how this is supposed to work
 * optionally, integrate with version control for quick synchronization






