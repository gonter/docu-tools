
=head1 NAME

  Tomboy

=head1 DESCRIPTION

utility functions to work with Tomboy

=head1 SYNOPSIS

  use Tomboy;

  $text2= Tomboy::link($text);
  $text2= Tomboy::list_item($text);

=head1 INTERNAL FUNCTIONS

=cut

package Tomboy;

use strict;

use UUID;
use POSIX;

sub link
{
  my $s= shift;
  '<link:internal>' . $s . '</link:internal>';
}

sub list_item
{
  my $s= shift;
  '<list-item dir="ltr">' . $s . '</list-item>';
}

=head2 ts_ISO ($time)

return timestamp in ISO format as used by Tomboy

=cut

sub ts_ISO
{
  my $time= shift || time ();
  my @ts= localtime ($time);
# sprintf ("%04d-%02d-%02dT%02d:%02d:%02d.0000000+01:00",
#          $ts[5]+1900, $ts[4]+1, $ts[3], $ts[2], $ts[1], $ts[0]);
  strftime ('%FT%T.000000%z', @ts);
}

sub get_uuid
{
  my ($uuid, $uuid_str);
  UUID::generate ($uuid);
  UUID::unparse ($uuid, $uuid_str);
  $uuid_str;
}

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

1;

