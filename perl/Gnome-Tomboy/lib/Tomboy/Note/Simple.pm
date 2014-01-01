#!/usr/bin/perl

package Tomboy::Note::Simple;

=head1 NAME

  Tomboy::Note::Simple

=head1 SYNOPSIS

  my $note= new Tomboy::Note::Simple (options => values);

=head2 parsing

  # version 1
  my $n1= parse Tomboy::Note::Simple ($note_fnm);

  # version 2
  my $n2= new Tomboy::Note::Simple; $n->parse ($note_fnm);

=head1 DESCRIPTION

Simple abstraction for notes written with Gnome's Tomboy.

The script uses XML::Parser in Tree style and uses it's parse
tree as the note's content datastructure (stored in "text").

=head1 BUGS

This module consists of originally two different ones, they are not
completely consistent.  The difference is how the content is stored.

In a .note file, contents looks like this:

 <text xml:space="preserve"><note-content version="0.1">title line
 content line2
 ...
 last content last</note-content></text>

 * Parser: based on XML::Parser, stores contents in
   @nc= @{$note->{'text'}->[2]} which represents the the <note-content>
   element, the first text-part starts at $nc[2]

 * Generator: contents (the stuff *in* the "note-content" element)
   is put into "lines" the first line, however, is stored in 'title'.

That should be further unified.

=cut

use strict;

use XML::Parser;
use JSON;
use Data::Dumper;
$Data::Dumper::Indent= 1;

use Tomboy;
use Util::XML_Parser_Tree;

my %fields=
(
  'title' => {},
  'last-change-date' => {},
  'last-metadata-change-date' => {},
  'create-date' => {},
  'cursor-position'          => { 'default' => 0 },
  'selection-bound-position' => { 'default' => -1, 'supress' => 1 },
  'width'  => { 'default' => 450 },
  'height' => { 'default' => 360 },
  'x'      => { 'default' => 0 },
  'y'      => { 'default' => 0 },
  'open-on-startup' => { 'default' => 'False' },
);

my @fields_date=     qw( last-change-date last-metadata-change-date create-date );
my @fields_default1= qw( cursor-position selection-bound-position width height x y );
my @fields_default2= qw( open-on-startup );
my @fields_seq1=     (@fields_date, @fields_default1);
my @fields_seq2=     (@fields_default2);

my ($s_text, $e_text)= ('<text xml:space="preserve">', '</text>');
my ($s_note_content, $e_note_content)= ('<note-content version="0.1">', '</note-content>');

sub new
{
  my $class= shift;

  my $title= 'New Note ' . Tomboy::ts_ISO ();
  my $note=
  {
    'lines' => [],
    'title' => $title,
  };
  foreach my $f (@fields_date)     { $note->{$f}= Tomboy::ts_ISO() }
  foreach my $f (@fields_default1) { $note->{$f}= $fields{'default'} }

  bless $note, $class;
  $note->set (@_);

  $note;
}

sub set
{
  my $note= shift;
  my %par= @_;

  foreach my $par (keys %par) { $note->{$par}= $par{$par} }
  1;
}

=head1 Group1: Parsing

=cut

sub empty_text
{
  my $note= shift;
  my $title= shift || 'empty text';

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
      $title,
    ]
  ];
  $note->{'title'}= $title;
  $note->{'lines'}= [ $title ];

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
    # print "create new c=[$c]\n";
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
  my $l1;
  eval { $l1= $p->parsefile($fnm, ErrorContext => 3) }; 
  if ($@)
  {
    print "parsefile failed fnm=[$fnm]:\n", $@, "\n";
    return undef;
  }

  # print "l1: ", Dumper ($l1);
  # my $s_l1= Util::XML_Parser_Tree::to_string (@$l1); print "s_l1=[$s_l1]\n";
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
          my $tag= $t2->[2];
          push (@{$note->{'tags'}}, $tag);

          if ($tag eq 'system:template')
          {
            $note->{'is_template'}= 1;
          }
          elsif ($tag =~ m#system:notebook:(.+)#)
          {
            $note->{'notebook'}= $1;
          }
          # TODO: maybe there other tags as well...
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

=head1 Group 1+2: glue

=cut

sub text_to_lines
{
  my $note= shift;

  my $x= $note->{'text'};

  # print "x: ", Dumper($x);

  my $nc= $x->[2];
  # print "nc: ", Dumper($nc);
  shift (@$nc); # remove the text-element's attributes
  my $s= Util::XML_Parser_Tree::to_string (@$nc);

  # split drops the new lines at the end, so we need to go the extra mile
  my $cnt= length ($1) if ($s=~ s#(\n+)$##);
  my @s= split ("\n", $s);
  for (my $i= 1; $i < $cnt; $i++) { push (@s, '') }

  # print "complete string: [$s]\n";
  # print "s: ", Dumper (\@s);
  # print "cnt: ", $cnt, "\n";

  my $title= $s[0];
  # TODO: compare existing title
  $note->{'title'}= $title unless ($note->{'title'});
  $note->{'lines'}= \@s;

  # ($title, @s);
  1;
}

sub parse_lines
{
  my $note= shift;

  # print "text: ", Dumper ($note->{'text'});
  my @lines= @{$note->{'lines'}};
  my $start= join ('', $s_text, $s_note_content, shift (@lines));
  my $x= parse_string (join ("\n", $start, @lines, join ('', $e_note_content, $e_text)));
  $note->{'text'}= $x->[1];
}

sub parse_string
{
  my $str= shift;

  # print "str=[$str]\n";
  my $p= new XML::Parser (Style => 'Tree');
  # print "p: ", Dumper ($p);
  my $l1;
  eval { $l1= $p->parsestring($str, ErrorContext => 3) }; 
  if ($@)
  {
    print "parsestring failed str=[$str]:\n", $@, "\n";
    return undef;
  }
  # print "l1: ", Dumper ($l1);
  $l1;
}

=head1 Group 2: text generator

=cut

sub add_lines
{
  my $note= shift;

  foreach my $line (@_)
  {
    my @lines= split (/\n/, $line);
    @lines= ('') unless (@lines);
    # print "line=[$line] lines: ", main::Dumper (\@lines);
    push (@{$note->{'lines'}}, @lines);
  }

  $note->{'e_updated'}= time();
}

sub save
{
  my $note= shift;
  my $out_dir= shift;
  my $fnm_out= shift;

  my ($title, $uuid, $ts_updated, $ts_md_updated, $ts_created, $e_updated, $lines, $is_template, $nb_name)=
    map { $note->{$_} } qw(title uuid last-change-date last-metadata-change-date create-date e_updated lines is_template notebook);

  # sanitize data
  $note->{'uuid'}= $uuid= Tomboy::get_uuid() unless ($uuid);
  $note->{'title'}= $title= $uuid unless ($title);

  if ($e_updated)
  {
    $note->{'last-metadata-change-date'}= $ts_md_updated=
    $note->{'last-change-date'}= $ts_updated= Tomboy::ts_ISO($e_updated);
  }

  $note->{'create-date'}= $ts_created= $ts_updated unless ($ts_created);

# print "tags: ", Dumper ($note->{'tags'});
  my @tags= ();
  push (@tags, 'system:template') if ($is_template);
  push (@tags, 'system:notebook:'. $nb_name) if ($nb_name);

  unless (defined ($fnm_out))
  {
    $fnm_out= $out_dir if ($out_dir);
    $fnm_out.= $uuid . '.note';
  }

  unless (open (FO, '>:utf8', $fnm_out))
  {
    print STDERR "can't write to [$fnm_out]\n";
    return undef;
  }

  print "writing note [$fnm_out]: [$title]\n"; # TODO: if verbose

  print FO chr(65279); # write a BOM, Tomboy seems to like that
  print FO <<EOX;
<?xml version="1.0" encoding="utf-8"?>
<note version="0.3" xmlns:link="http://beatniksoftware.com/tomboy/link" xmlns:size="http://beatniksoftware.com/tomboy/size" xmlns="http://beatniksoftware.com/tomboy">
EOX
  print FO '  <title>'. Util::XML_Parser_Tree::tlt($title) ."</title>\n";
  print FO '  ', $s_text, $s_note_content;

  foreach my $line (@$lines)
  {
    print FO $line, "\n";
  }

  print FO $e_note_content, $e_text, "\n";

  foreach my $f (@fields_seq1)
  {
    print_attribute (*FO, $note, $f);
  }

  if (@tags)
  {
    print FO "  <tags>\n";
    foreach my $tag (@tags) { print FO "    <tag>", $tag, "</tag>\n"; }
    print FO "  </tags>\n";
  }

  foreach my $f (@fields_seq2)
  {
    print_attribute (*FO, $note, $f);
  }

  print FO "</note>"; # No newline at end of file, that's how Tomboy does that ...
  close (FO);

  $fnm_out;
}

sub print_attribute
{
  local *F= shift;
  my $n= shift;
  my $f= shift;

    my $a= $n->{$f};
    unless (defined ($a))
    {
      my $x= $fields{$f};
      return if (exists ($x->{'supress'})); # supress the default for that one
      my $b;
      if (exists ($x->{'default'})) { $b= $x->{'default'} }
      # TODO: elsif exists function ....
      $n->{$f}= $a= $b if (defined ($b));
    }

  print F '  <', $f, '>', $a, '</', $f, ">\n";
}

__END__

=head1 AUTHOR

  Gerhard Gonter <ggonter@gmail.com>

=head1 BUGS

* XML::Parser throws exceptions, these are currently not handled well.

=cut

  <tags>
    <tag>system:notebook:Kalender 2014</tag>
  </tags>

Template:
  <tags>
    <tag>system:template</tag>
    <tag>system:notebook:Kalender 2014</tag>
  </tags>

1;

