#
# scan directory with note files in Tomboy format
#

=head1 NAME

  Tomboy::Directory

=head1 SYNOPSIS

=head1 DESCRIPTION

process a directory containing note files in Tomboy format

=head1 SYNOPSIS

  my $tb_dir= new Tomboy::Directory;
  $tb_toc= $tb_dir->scan_dir ($directory);

=cut

package Tomboy::Directory;

use strict;

use Data::Dumper;
$Data::Dumper::Indent= 1;

use Tomboy::Note::Simple;

# attributes read from the note itself or from the filesystem
my @TB_note_attrs= qw(title create-date last-change-date last-metadata-change-date notebook is_template fnm);
my @TB_meta_attrs= qw(uuid mtime size ino);
=head1 METHODS

=head2 my $tb_dir= new Tomboy::Directory()

creates a new directory object

=cut

sub new
{
  my $class= shift;
  my %par= @_;

  my $obj= {};
  bless $obj, $class;

  foreach my $par (keys %par)
  {
    $obj->{$par}= $par{$par};
    if ($par eq 'dir') { $obj->scan_dir ($par{$par}) }
  }

  $obj;
}

=head2 $tb_dir->scan_dir ($directory, ($rows, $quick]))

Scan named directory for Tomboy notes and extract key features using
Tomboy::Note::Simple.  These features are placed into a record and all
these records are returned as array reference.

Optionally pass an array reference of such records as $rows and when
$quick has a true value, the note files are only processed when they
do not appear to be modified, otherwise the earlier record is passed in
the result set.

=cut

sub scan_dir
{
  my $obj=   shift;
  my $dir=   shift;
  my $rows=  shift; # contents of an earlier scan
  my $quick= shift; # 0/undef: full scan
                    # 1: quick scan

  $dir=~ s#/+$##;
  unless (opendir (DIR, $dir))
  {
    print "ATTN: can't read directory [$dir]\n";
    return undef;
  }

  my %fnm;
  if (defined ($quick) && defined ($rows))
  {
    print "scan_dir: quick=[$quick]\n";
    # print "rows: ", Dumper ($rows);
    %fnm= map { $_->{'fnm'} => $_ } @$rows;
    # print "fnm: ", Dumper (\%fnm);
  }
  else
  {
    $quick= 0;
  }

  my @res= ();
  my ($cnt_added, $cnt_updated, $cnt_unchanged)= (0, 0, 0);
  NOTE: while (my $e= readdir (DIR))
  {
    next NOTE if ($e eq '.' || $e eq '..');
    next NOTE unless ($e =~ /(.+)\.note$/);
    my $fnm_uuid= $1;

    my $fp= join ('/', $dir, $e);
    # print "reading note [$fp]\n"; # TODO: if verbose...
    my @st= stat ($fp);
    unless (@st)
    {
      print "ATTN: can't stat '$fp'\n";
      next NOTE;
    }

    if ($quick)
    {
      my $x_rec= $fnm{$fp};

      if (defined ($x_rec))
      {
        if ($x_rec->{'mtime'}   == $st[9]
            && $x_rec->{'size'} == $st[7]
            && $x_rec->{'ino'}  == $st[1]
           )
        {
          $cnt_unchanged++;
          push (@res, $x_rec);
          next NOTE;
        }
        else
        {
          print "updated: $fp\n";
          $cnt_updated++;
        }
      }
      else
      {
        print "added: $fp\n";
        $cnt_added++;
      }
    }

    my $n= parse Tomboy::Note::Simple ($fp);

    unless (defined ($n))
    {
      print "ATTN: parsing [$fp] returned undefined note!\n";
      next NOTE;
    }
    # print "n: ", main::Dumper ($n);

    my %rec= map { $_ => $n->{$_} } @TB_note_attrs;
    $rec{'uuid'}= $fnm_uuid;
    $rec{'mtime'}= $st[9];
    $rec{'size'}= $st[7];
    $rec{'ino'}= $st[1];

    # $rec{'present'}= 1; # flag to indicate which objects were dropped

    push (@res, \%rec);
  }

  closedir (DIR);

# TODO: list dropped files
# TODO: save statistics and/or file status for later processing

  print "statistics: cnt_added=$cnt_added cnt_updated=$cnt_updated cnt_unchanged=$cnt_unchanged\n";
  (wantarray) ? @res : \@res;
}

=head2 $tb_dir->TB_attrs

return a list of directory attributes

=cut

sub TB_attrs
{
  my $s= shift;
  return (@TB_meta_attrs, @TB_note_attrs);
}

1;

