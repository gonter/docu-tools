#!/usr/bin/perl

package Tomboy::TOC;

use strict;

use Tomboy::Directory;

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

=head2 $toc->find($pattern [, $where])

Search TOC for matching $pattern in field specified by $where; if $where is not defined, 'title' is used.

Returns a list of matching TOC entries

=cut

sub find
{
  my $self= shift;
  my $pattern= shift;
  my $where= shift || 'title';

print "find: where=[$where] pattern=[$pattern]\n";
  my ($mode, $toc, $rows)= $self->load_toc();
  my @res;
  foreach my $row (@$rows)
  {
    next unless ($row->{$where} =~ m#$pattern#i);
    # print "row: ", main::Dumper ($row);
    push (@res, $row);
  }
  @res;
}

# Note: there is also a Tomboy::Directoy::scan_dir()
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

1;

