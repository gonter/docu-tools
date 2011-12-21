#!/usr/local/bin/perl
# $Id: x1.pl,v 1.3 2011/12/19 08:26:18 gonter Exp $

=pod

=head1 NAME

Script to process the XML dump of a Confluence Wiki, see
perldoc Wiki::Confluence for more details about that.

=cut

use strict;

# use lib 'lib';
use Wiki::Confluence;
use Data::Dumper;
$Data::Dumper::Indent= 1;

my $x_flag= 0;

my @JOBS;
my $arg;
while (defined ($arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
       if ($arg eq '-h') { &usage; exit (0); }
    elsif ($arg eq '-x') { $x_flag= 1; }
    elsif ($arg eq '--') { push (@JOBS, @ARGV); @ARGV= (); }
    else { &usage; }
    next;
  }

  push (@JOBS, $arg);
}

while (defined ($arg= shift (@JOBS)))
{
  &analyze_cfl_dump ($arg);
}

exit (0);

sub usage
{
  print <<EOX;
usage: $0 [-opts] pars

options:
-h  ... help
-x  ... set x flag
--  ... remaining args are parameters
EOX
}

# ----------------------------------------------------------------------------
sub analyze_cfl_dump
{
  my $fnm= shift;

  print "main_function: $fnm\n";
  my $cfl= new Wiki::Confluence ('entities' => $fnm);
  # print "cfl: ", Dumper ($cfl);
  $cfl->stats ();

  my $t= $cfl->{'_TWIG_'};
  delete ($cfl->{'_TWIG_'});
  print "cfl page tree: ", Dumper ($cfl->{'_pt_'});
}

# ----------------------------------------------------------------------------
sub hex_dump
{
  my $data= shift;
  local *FX= shift || *STDOUT;

  my $off= 0;
  my ($i, $c, $v);

  while ($data)
  {
    my $char= '';
    my $hex= '';
    my $offx= sprintf ('%08X', $off);
    $off += 0x10;

    for ($i= 0; $i < 16; $i++)
    {
      $c= substr ($data, 0, 1);

      if ($c ne '')
      {
        $data= substr ($data, 1);
        $v= unpack ('C', $c);
        $c= '.' if ($v < 0x20 || $v >= 0x7F);

        $char .= $c;
        $hex .= sprintf (' %02X', $v);
      }
      else
      {
        $char .= ' ';
        $hex  .= '   ';
      }
    }

    print FX "$offx $hex |$char|\n";
  }
}

=cut

=head1 AUTHOR

Gerhard Gonter, C<< <ggonter at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Gerhard Gonter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=over

