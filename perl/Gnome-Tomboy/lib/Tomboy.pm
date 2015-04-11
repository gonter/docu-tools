#!/usr/bin/perl

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

use POSIX;

eval {
  require UUID;

  sub get_uuid
  {
    my ($uuid, $uuid_str);
    UUID::generate ($uuid);
    UUID::unparse ($uuid, $uuid_str);
    $uuid_str;
  }
};

if ($@)
{
  print "no UUID\n";
  eval {
    use Data::UUID;

    sub get_uuid2
    {
      my $uc= new Data::UUID;
      my $str= $uc->create_str();
      $str =~ tr/A-F/a-f/;
      $str;
    }
    *get_uuid= *get_uuid2;
  };
  if ($@) { die "install either UUID or Data::UUID"; }

}


my %options_passed= map { $_ => 1 } qw(--note-path); # used by start_tb() function

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

sub start_tb
{
  my %par= @_;

  my @cmd= ('tomboy');
  foreach my $what (keys %par)
  {
    my $par= $par{$what};

    if ($what eq 'uuid')
    {
      push (@cmd, '--open-note', 'note://tomboy/'. $par);
    }
    elsif (exists ($options_passed{$what}))
    {
      push (@cmd, $what, $par);
    }
  }

  print ">>> ", join (' ', @cmd), "\n";
  my $pid= fork();
  if ($pid == 0) { exec @cmd; }
  print "started pid=[$pid]\n";

  $pid;
}

1;

