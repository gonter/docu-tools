#!/usr/bin/perl

use strict;

use Data::Dumper;
$Data::Dumper::Indent= 1;
use XML::Parser;

use Util::XML_Parser_Tree;

my @str=
(
  "<&>",
  "\x{2028} Einheitssachtitel Don't stand where the comet",
);

# binmode (STDOUT, ':utf8');
foreach my $str (@str)
{
  # print "[$str]\n";

  my $s_enc= Util::XML_Parser_Tree::tlt_str ($str);
  print "str=[$str]\n";
  print "s_enc=[$s_enc]\n";
  my $s_enc_wrapped=
    '<?xml version="1.0" encoding="utf-8"?>'
    .'<test>'.$s_enc.'</test>';
  print "s_enc_wrapped=[$s_enc_wrapped]\n";
  my $pt= parse_string ($s_enc_wrapped);
  print "pt: ", Dumper ($pt);
}

sub parse_string
{
  my $str= shift;

  print "str=[$str]\n";
  my $p= new XML::Parser (Style => 'Tree', 'ProtocolEncoding' => 'UTF-8');
  # print "p: ", Dumper ($p);
  my $l1;
  eval { $l1= $p->parse($str, ErrorContext => 3, 'ProtocolEncoding' => 'UTF-8') }; 
  if ($@)
  {
    print "parse failed str=[$str]:\n", $@, "\n";
    return undef;
  }
  # print "l1: ", Dumper ($l1);

  $l1;
}

