#!/usr/bin/perl

package Tomboy::Note::Simple;

=head1 NAME

  Tomboy::Note::Simple;

=head1 SYNOPSIS

  # version 1
  my $n1= parse Tomboy::Note::Simple ($note_fnm);

  # version 2
  my $n2= new Tomboy::Note::Simple; $n->parse ($note_fnm);

=head1 DESCRIPTION

Simple abstraction for notes written with Gnome's Tomboy.

The script uses XML::Parser in Tree style and uses it's parse
tree as the note's content datastructure.

=cut

use strict;

use XML::Parser;
use JSON;
use Data::Dumper;
$Data::Dumper::Indent= 1;

my %fields=
(
  'title' => {},
  'last-change-date' => {},
  'last-metadata-change-date' => {},
  'create-date' => {},
  'cursor-position' => {},
  'selection-bound-position' => {},
  'width' => {},
  'height' => {},
  'x' => {},
  'y' => {},
  'open-on-startup' => {},
);

sub new
{
  my $class= shift;
  my %par= @_;

  my $note= {};
  bless $note, $class;

  foreach my $par (keys %par)
  {
    $note->{$par}= $par{$par};
  }

  $note;
}

sub empty_text
{
  my $note= shift;

  $note->{'text'}= [
    {
      'xml:space' => 'preserve'
    },
    'note-content',
    [
      {
        'version' => '0.1'
      },
      0,
      'empty text'
    ]
  ];

  1;
}

sub parse
{
  my $c= shift;
  my $fnm= shift;

  my $note;
     if (ref ($c) eq 'Tomboy::Note::Simple') { $note= $c; }
  elsif (ref ($c) eq '')
  {
    print "create new c=[$c]\n";
    $note= new Tomboy::Note::Simple;
  }
  else
  {
    print "unknown c=[$c] r=[", ref ($c), "]\n";
  }
  # print "note=[$note]\n";
  $note->{'fnm'}= $fnm;

  my $p= new XML::Parser (Style => 'Tree');
  # print "p: ", Dumper ($p);
  my $l1= $p->parsefile($fnm, ErrorContext => 3);
  # print "l1: ", Dumper ($l1);
  my ($tag, $nc, @rest)= @$l1;
  # print "res: ", Dumper ($res);

  if ($tag ne 'note' || (my $r= ref ($nc)) ne 'ARRAY')
  {
    print "unknown format fnm=[$fnm] tag=[$tag] r=[$r]\n";
    return undef;
  }
  # || @rest)

  my $attr= shift (@$nc);
  # print "attr: ", main::Dumper ($attr);
  $note->{'attr'}= $attr;

  while (@$nc)
  {
    my $k= shift (@$nc);
    my $v= shift (@$nc);
    next if ($k eq '0');

    if ($k eq 'text')
    {
      # print "text: ", main::Dumper ($v);
      $note->{'text'}= $v;
    }
    elsif ($k eq 'tags')
    {
      # print "tags: ", main::Dumper ($v);
      shift (@$v); # attributes of "tags"
      while (@$v)
      {
        my $t1= shift (@$v);
        my $t2= shift (@$v);
        # print "t1=[$t1] t2=[$t2]\n";

           if ($t1 eq '0') {} # skip text
        elsif ($t1 eq 'tag')
        {
          # print "t2: [$t2]\n";
          push (@{$note->{'tags'}}, $t2->[2]);
# ZZZ
        }
      }
    }
    elsif (exists ($fields{$k}))
    {
      $note->{$k}= $v->[2];
    }
    else
    {
      print "unknown field k: [$k] ", main::Dumper ($v);
    }
  }

  $note;
}

1;

__END__

=head1 AUTHOR

  Gerhard Gonter <ggonter@gmail.com>

=cut
