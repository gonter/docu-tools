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

=head1 NOTES

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

my $VERSION= 0.004;

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

my $empty_text=
[
    {
      'xml:space' => 'preserve'
    },
    'note-content',
    [
      {
        'version' => '0.1'
      }
    ]
];

=head2 new ((attributes => values)*)

Create a new (empty) note and optionlly set attributes

=cut

sub new
{
  my $class= shift;

  my $title= 'New Note ' . Tomboy::ts_ISO ();
  my $note=
  {
    'title' => $title,
    'lines' => [],
    'text' => undef,

    # flags to indicate if 'lines' or 'text' is up to date:
    'flg_text'  => 1,
    'flg_lines' => 1,
  };
  foreach my $f (@fields_date)     { $note->{$f}= Tomboy::ts_ISO() }
  foreach my $f (@fields_default1) { $note->{$f}= $fields{'default'} }

  bless $note, $class;
  $note->set (@_);

  $note;
}

=head2 $note->set ((attributes => values)*)

Set attribute values without checking.

=cut

sub set
{
  my $note= shift;
  my %par= @_;

  foreach my $par (keys %par) { $note->{$par}= $par{$par} }
  1;
}

=head1 Group1: Parsing

=cut

# dunno if this is really useful
sub empty_text
{
  my $note= shift;
  my $title= shift || 'empty text';

=begin comment

  my $x= $note->{'text'}= $empty_text;
  push (@{$x->[1]}, '0', $title);

=end comment
=cut

  $note->{'title'}= $title;
  $note->{'lines'}= [ $title ];
  $note->parse_lines();

  1;
}

=head2 $note->parse ($filename)

=head2 $note= parse Tomboy::Note::Simple ($filename)

Parse given file using XML::Parser in "Tree" style.

=cut

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

  my $p= new XML::Parser (Style => 'Tree'); # ProtocolEncoding should be derived from the file's PI
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

  $note->{'flg_text'}= 1;
  $note->{'flg_lines'}= 0;

  $note;
}

=head1 Group 1+2: glue

=head2 $note->update()

Refresh 'text' or 'lines' if one of them is outdated.

=cut

sub update
{
  my $note= shift;

     if ($note->{'flg_text'})  { $note->text_to_lines(); }
  elsif ($note->{'flg_lines'}) { $note->parse_lines();   }
  else { return undef; }

  1;
}

=head2 $note->text_to_lines()

Refresh 'lines' from 'text'.

Compare with set_lines() below.

=cut

sub text_to_lines
{
  my $note= shift;

  my $nc= $note->get_note_content();
  my $s= Util::XML_Parser_Tree::to_string (@$nc);

  # split drops the newlines at the end, so we need to go the extra mile
  my $cnt= ($s=~ s#(\n+)$##) ? length ($1) : 0;
  my @s= split ("\n", $s);
  for (my $i= 1; $i < $cnt; $i++) { push (@s, '') }

  # print "complete string: [$s]\n";
  # print "s: ", Dumper (\@s);
  # print "cnt: ", $cnt, "\n";

  my $title= $s[0];
  # TODO: compare existing title
  $note->{'title'}= $title unless ($note->{'title'});
  $note->{'lines'}= \@s;
  # NOTE: maybe setting a proper title should be a separate method

  # ($title, @s);
  $note->{'flg_text'}= 1;  # if 'lines' are generated from 'text', then both must be up-to-date
  $note->{'flg_lines'}= 1;

  1;
}

=head2 $note->parse_lines()

Refresh 'text' from 'lines'.

=cut

sub parse_lines
{
  my $note= shift;

  # print "text: ", Dumper ($note->{'text'});
  my @lines= @{$note->{'lines'}};

  my $x= parse_string (wrap_lines ($note->{'lines'}));

  $note->{'text'}= $x->[1];

  $note->{'flg_text'}= 1;  # if 'text' is parsed from 'lines', then both must be up-to-date
  $note->{'flg_lines'}= 1;

  1;
}

=head1 ACCESSORS

=head2 $old_title= $note->set_title ($new_title)

Update the title of a note.

Currently, the title is not sanitized at all.

=cut

sub set_title
{
  my $note= shift;
  my $title= shift;

  my $old_title= $note->{'title'};

  # TODO: sanitize the title (e.g. remove XML tags which are sometimes
  #       present in the note's first line)
  $note->{'title'}= $title;

  $old_title;
}

=head2 $xml_tree= $note->get_text()

Retrieves the 'text' component (refreshing it, if necessary) and returns
the XML::Parser tree structure.

=cut

sub get_text
{
  my $note= shift;

  $note->update() unless ($note->{'flg_text'});
  # my $t= $note->get_note_content();
  my @t= @{$note->{'text'}};
  shift (@t);
  (wantarray) ? @t : \@t;
}

sub set_text
{
  my $note= shift;
  my $new_text= shift;

  my $old_text= $note->{'text'};
  my @new_text= ($old_text->[0], @$new_text);
  $note->{'text'}= \@new_text;

  $note->{'flg_lines'}= 0;
  $note->{'flg_text'}= 1;

  $old_text;
}

=head2 $line_list= $note->get_lines()

Retrieves the 'lines' component (refreshing it, if necessary) and returns
the a hash ref of all lines

=cut

sub get_lines
{
  my $note= shift;

  $note->update() unless ($note->{'flg_lines'});
  $note->{'lines'};
}

sub set_lines
{
  my $note= shift;
  my $new_lines= shift;

  unless (ref ($new_lines) eq 'ARRAY')
  { # we want an array ref, fix that

    # split drops the newlines at the end, so we need to go the extra mile
    my $cnt= ($new_lines=~ s#(\n+)$##) ? length ($1) : 0;
    my @s= split ("\n", $new_lines);
    for (my $i= 1; $i < $cnt; $i++) { push (@s, '') }

    $new_lines= \@s;
  }

  my $old_lines= $note->{'lines'};
  $note->{'lines'}= $new_lines;

  $note->{'flg_lines'}= 1;
  $note->{'flg_text'}= 0;

  $old_lines;
}

sub get_note_content
{
  my $note= shift;

  my $x= $note->{'text'};
  # print "x: ", Dumper($x);

  my @nc= @{$x->[2]};
  # print "nc: ", Dumper(\@nc);
  shift (@nc); # remove the text-element's attributes

  (wantarray) ? @nc : \@nc;
}

sub set_note_content
{
  my $note= shift;
  my $new_nc= shift;

  my $x= $note->{'text'};
  my $old_nc= $x->[2];
  my @new_nc= ($old_nc->[0], @$new_nc);
  $x->[2]= \@new_nc;

  # TODO/NOTE: update flags?

  $old_nc;
}


=head1 Group 2: text generator

=head2 $note->add_lines ( array of text lines )

Push additional lines to 'lines', invalidates 'text'.

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

  $note->{'flg_lines'}= 1;
  $note->{'flg_text'}= 0;

  $note->{'e_updated'}= time();
}

=head2 $note->save ($out_dir|undef, $out_fnm|undef)

Save the note, the filename can either be specified or will be generated.
Both $out_dir and $out_fnm are optional but $out_fnm takes precedence.

=cut

sub save
{
  my $note= shift;
  my $out_dir= shift;
  my $fnm_out= shift;

  # refresh lines, if they are not up-to-date
  $note->update() unless ($note->{'flg_lines'});

  my ($title, $uuid, $lines, $ts_updated, $ts_md_updated, $ts_created,
      $e_updated, $is_template, $nb_name)=
    map { $note->{$_} } qw(title uuid lines last-change-date
         last-metadata-change-date create-date e_updated is_template
         notebook);

  # sanitize data
  $note->{'uuid'}= $uuid= Tomboy::get_uuid() unless ($uuid);
  $note->{'title'}= $title= $uuid unless ($title);
    # NOTE: Hmm... maybe we should use the first line here.

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
    $fnm_out= $out_dir.'/' if ($out_dir);
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
  print FO '  <title>'. Util::XML_Parser_Tree::tlt_str($title) ."</title>\n";
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

=head1 INTERNAL FUNCTIONS

=head2 print_attribute ($fh, $note, $field)

Print a XML rendering of given Tomboy attribute to $fh, apply (and set)
default values, if value is not defined.

=cut

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

sub wrap_lines
{
  my $l= shift;

  my @lines;
  if (ref ($l) eq 'ARRAY') { @lines= @$l; }
  else { @lines= ($l, @_); } # assume we received an array

  my $start= join ('', $s_text, $s_note_content, shift (@lines));
  join ("\n", $start, @lines, join ('', $e_note_content, $e_text));
}

=head2 parse_string ($str)

Uses XML::Parser in "Tree" style to parse a text block (multiple lines)
in one string.

Returns the parse tree or undef.

=cut

sub parse_string
{
  my $str= shift;

  # print "str=[$str]\n";
  my $p= new XML::Parser (Style => 'Tree', 'NoExpand' => 1);
  # print "p: ", Dumper ($p);
  my $l1;
  eval { $l1= $p->parse($str, ErrorContext => 3, 'ProtocolEncoding' => 'UTF-8') }; 
  if ($@)
  {
    print "parsestring failed str=[$str]:\n", $@, "\n";
    return undef;
  }
  # print "l1: ", Dumper ($l1);

  $l1;
}

1;

__END__

=head1 AUTHOR

  Gerhard Gonter <ggonter@cpan.org>

=head1 BUGS, PROBLEMS, NOTES

 * XML::Parser throws exceptions, these are currently not handled well.
 * The last newline in the note tends to be removed, however, the note
   will end with one newline, if there was none before.
 * $note->save() will not use the same filename from the parse() method,
   instead, a new one will be generated.  You have to specify the
   filename, if need, e.g. $note->save(undef, $note->{'fnm'});
 * The POD needs some attention.

=cut

