#!/usr/bin/perl

use strict;

use UUID;
use Data::UUID;

for (my $i= 0; $i< 10; $i++)
{
  my $u1= get_uuid_1();
  my $u2= get_uuid_2();
  printf ("%3d %s %s\n", $i, $u1, $u2);
}

sub get_uuid_1
{
  my ($uuid, $uuid_str);
  UUID::generate ($uuid);
  UUID::unparse ($uuid, $uuid_str);
  $uuid_str;
}

sub get_uuid_2b
{
# generates the same string all the time.
  my $uc= new Data::UUID;
  my $ui= $uc->create_from_name(NameSpace_OID, "at.urxn");
  my $str= $uc->to_string($ui);
  $str =~ tr/A-F/a-f/;
  $str;
}

sub get_uuid_2
{
  my $uc= new Data::UUID;
  my $str= $uc->create_str();
  $str =~ tr/A-F/a-f/;
  $str;
}

