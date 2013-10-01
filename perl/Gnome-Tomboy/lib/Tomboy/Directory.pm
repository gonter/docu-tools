#
# scan directory with note files in Tomboy format
#

=head1 NAME

  Tomboy::Directory;

=head1 SYNOPSIS

=head1 DESCRIPTION

process a directory containing note files in Tomboy format

=cut

package Tomboy::Directory;

use strict;

use Tomboy::Note::Simple;

my @TB_note_attrs= qw(title create-date last-change-date last-metadata-change-date);
my @TB_meta_attrs= qw(uid notebook);
sub TB_attrs { return (@TB_meta_attrs, @TB_note_attrs) }

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

sub scan_dir
{
  my $obj= shift;
  my $dir= shift;

  unless (opendir (DIR, $dir))
  {
    print "ATTN: can't read directory [$dir]\n";
    return undef;
  }

  my @res= ();
  NOTE: while (my $e= readdir (DIR))
  {
    next NOTE if ($e eq '.' || $e eq '..');
    next NOTE unless ($e =~ /(.+)\.note$/);
    my $uid= $1;

    my $fp= join ('/', $dir, $e);
    # print "reading note [$fp]\n"; # TODO: if verbose...
    my $n= parse Tomboy::Note::Simple ($fp);

    unless (defined ($n))
    {
      print "ATTN: parsing [$fp] returned undefined note!\n";
      next NOTE;
    }

    my %rec= map { $_ => $n->{$_} } @TB_note_attrs;
    $rec{'uid'}= $uid;

    foreach my $tag (@{$n->{'tags'}})
    {
      if ($tag =~ m#system:notebook:(.+)#) { $rec{'notebook'}= $1 }
    }

    push (@res, \%rec);
  }

  closedir (DIR);

  (wantarray) ? @res : \@res;
}

1;

