#!/usr/bin/perl

=head1 NAME

  s2.pl

=head1 DESCRIPTION

Script to play with Tomboy::Directory for testing.

Generates a CSV file as TOC (table of contents) which might be useful.

=head1 OPTIONS

  -f ... find-mode
  -s ... scan-mode (default)
  -d <dir> ... directory where notes are stored; (default: ~/.local/share/tomboy)
  -t <toc> ... Table-Of-Contents (TOC) of all notes; (default: Tomboy-TOC.csv)
  -e ... start Tomboy; useful with in find-mode

=head1 MODES

=head2 scan-mode

Scan Tomboy notes directory and save a table of contents in a CSV file (fields are TAB separated).

=head2 find-mode

Load table of contents from CSV file and find notes which match given find patterns.
If -e is also specified, tell Tomboy to open these notes.

=cut

use strict;

use lib 'lib';

use Util::Simple_CSV;
use Data::Dumper;
$Data::Dumper::Indent= 1;

# use Tomboy::Note::Simple;
use Tomboy::Directory;
use Tomboy::TOC;

my $toc_file;
my $note_dir= $ENV{'HOME'} . '/.local/share/tomboy';

my $mode= 'scan';
my $start_tb= 0;

my @PAR= ();
while (my $arg= shift (@ARGV))
{
  if ($arg =~ /^-/)
  {
       if ($arg eq '-f') { $mode= 'find'; }
    elsif ($arg eq '-s') { $mode= 'scan'; }
    elsif ($arg eq '-d') { $note_dir= shift (@ARGV); }
    elsif ($arg eq '-t') { $toc_file= shift (@ARGV); }
    elsif ($arg eq '-e') { $start_tb= 1; }
    else { usage(); }
  }
  else
  {
    push (@PAR, $arg);
  }
}

$toc_file= join ('/', $note_dir, 'Tomboy-TOC.csv') unless (defined ($toc_file));
my $toc= new Tomboy::TOC('note_dir' => $note_dir, 'toc_file' => $toc_file);
print "toc: ", Dumper ($toc);

if ($mode eq 'scan')
{
  $toc->scan_dir();
}
elsif ($mode eq 'find')
{
  my %uuid;
  foreach my $pattern (@PAR)
  {
    my @res= $toc->find ($pattern);
    foreach my $res (@res) { $uuid{$res->{'uuid'}}= $res; } # TODO: count hits
  }

  foreach my $uuid (keys %uuid)
  {
    if ($start_tb)
    {
      Tomboy::start_tb ('uuid', $uuid);
    }
    else
    {
      print Dumper ($uuid{$uuid});
    }
  }
}

exit (0);

sub usage
{
  system ('perldoc', $0);
  exit;
}

=begin comment

hmm... starting Tomboy does not work as expected.  When tomboy is
already running, calling it is fine, otherwise, it has to be started
in the background and given some time before it can be called again.
Probably it would make sense to do something with D-Bus here...

=end comment
=cut

__END__

=head1 TODO

 * enhance this to create a standalone script (e.g. tbshow)
 * cache the data in ~/.gcache ?? check out how this is supposed to work
 * optionally, integrate with version control for quick synchronization

=head1 NOTES

=head2 Directories used by Tomboy on Ubuntu

 * ~/.cache/tomboy/  ... empty
 * ~/.gconf/apps/tomboy/
   %gconf.xml
   global_keybindings/%gconf.xml
 * ~/.config/tomboy/ ... various stuff






