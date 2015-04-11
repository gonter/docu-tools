#!/usr/bin/perl

use strict;

use POSIX;

eval {
  require UUID;

  sub get_uuid_1
  {
    my ($uuid, $uuid_str);
    UUID::generate ($uuid);
    UUID::unparse ($uuid, $uuid_str);
    $uuid_str;
  }
};

if ($@)
{
  print "no UUID package\n";

  require Data::UUID;
  sub get_uuid_1
  {
    get_uuid_2();
  }
}


my $max= shift (@ARGV) || 10;

for (my $i= 0; $i< $max; $i++)
{
  my $u1= get_uuid_1();
  my $u2= get_uuid_2();
  my $ts= ts_iso();
  printf ("%5d %s %s %s\n", $i, $ts, $u1, $u2);
}

=begin junk

sub get_uuid_2b
{
# generates the same string all the time.
  my $uc= new Data::UUID;
  my $ui= $uc->create_from_name(NameSpace_OID, "at.urxn");
  my $str= $uc->to_string($ui);
  $str =~ tr/A-F/a-f/;
  $str;
}

=end junk
=cut

sub get_uuid_2
{
  my $uc= new Data::UUID;
  my $str= $uc->create_str();
  $str =~ tr/A-F/a-f/;
  $str;
}

sub ts_iso
{
  my $ts_iso= strftime ('%FT%T.000000%z', localtime(time()));
  # print "ts_iso=[$ts_iso]\n";
  $ts_iso;
}

