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
my $note_dir= '~/Tomboy';

my $mode= 'scan';
my $start_tb= 0;

my @PAR= ();
while (my $arg= shift (@ARGV))
{
  if ($arg =~ /^-/)
  {
       if ($arg eq '-f') { $mode= 'find'; }
    elsif ($arg eq '-d') { $note_dir= shift (@ARGV); }
    elsif ($arg eq '-e') { $start_tb= 1; }
    else { usage(); }
  }
  else
  {
    push (@PAR, $arg);
  }
}

my $bli= new bli('note_dir' => $note_dir, 'toc_file' => $toc_file);
print "bli: ", Dumper ($bli);

if ($mode eq 'scan')
{
  $bli->scan_dir();
}
elsif ($mode eq 'find')
{
  my %uuid;
  foreach my $pattern (@PAR)
  {
    my @res= $bli->find ($pattern);
    foreach my $res (@res) { $uuid{$res->{'uuid'}}= $res; } # TODO: count hits
  }

  foreach my $uuid (keys %uuid)
  {
    if ($start_tb)
    {
      start_tb ('uuid', $uuid);
    }
    else
    {
      print Dumper ($uuid{$uuid});
    }
  }
}

=begin comment

hmm... starting Tomboy does not work as expected.  When tomboy is
already running, calling it is fine, otherwise, it has to be started
in the background and given some time before it can be called again.
Probably it would make sense to do something with D-Bus here...

=end comment
=cut

sub start_tb
{
  my $what= shift;
  my $par= shift;

  if ($what eq 'uuid')
  {
    my @cmd= ('tomboy', '--open-note', 'note://tomboy/'. $par);
    print ">>> ", join (' ', @cmd), "\n";

    my $pid= fork();
    if ($pid == 0) { exec @cmd; }
    print "started pid=[$pid]\n";
  }
}

exit (0);

package bli;

sub new
{
  my $class= shift;

  my $self= {};
  bless $self, $class;
  $self->set (@_);

  $self;
}

sub set
{
  my $self= shift;
  my %par= @_;

  foreach my $par (keys %par) { $self->{$par}= $par{$par}; }
}

sub find
{
  my $self= shift;
  my $pattern= shift;

print "find: pattern=[$pattern]\n";
  my ($mode, $toc, $rows)= $self->load_toc();
  my @res;
  foreach my $row (@$rows)
  {
    next unless ($row->{'title'} =~ m#$pattern#i);
    # print "row: ", main::Dumper ($row);
    push (@res, $row);
  }
  @res;
}

sub scan_dir
{
  my $self= shift;

print main::Dumper ($self);
  my ($note_dir, $toc_file)= map { $self->{$_} } qw(note_dir toc_file);

  $note_dir=~ s#/+$##;
  my $tb_d= new Tomboy::Directory ();
  # print "tb_d: ", Dumper ($tb_d);
  print "scanning [$note_dir]\n";

  my ($mode, $toc, $rows)= $self->load_toc();

  my $toc_data= $tb_d->scan_dir ($note_dir, $rows, $mode);
  # TODO: if verbose or so print "toc_data: ", Dumper ($toc_data);

  $toc->{'data'}= $toc_data;
  # TODO: optionally sort the returned values
  $toc->sort ('uuid');
  # print "toc: ", Dumper ($toc);
  $toc->save_csv_file ('filename' => $toc_file, 'separator' => "\t", 'UTF8' => 1);
}

sub load_toc
{
  my $self= shift;

  my $mode= 0;
  my $toc;

print "load_toc\n";
  return (1, $toc, $toc->{'data'}) if (defined ($toc= $self->{'_toc'}));

  my ($toc_file)= map { $self->{$_} } qw(toc_file);
print "load_toc: toc_file=[$toc_file]\n";

  my $toc= new Util::Simple_CSV ('UTF8' => 1, 'no_array' => 1, 'separator' => "\t", 'UTF8' => 1);
  my $rows= [];
  if (-f $toc_file)
  {
    print "loading $toc_file\n";
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
    $toc->define_columns (Tomboy::Directory::TB_attrs());
  }
  $self->{'_toc'}= $toc;

  ($mode, $toc, $rows);
}

__END__

=head1 TODO

 * enhance this to create a standalone script (e.g. tbshow)
 * cache the data in ~/.gcache ?? check out how this is supposed to work
 * optionally, integrate with version control for quick synchronization

=head1 NOTES

=head2 Directories used by Tomboy on Ubuntu

 * ~/.cache/tomboy/  ... empty
 * ~/.gconf/tomboy/
    %gconf.xml
 * ~/.config/tomboy/ ... various stuff






