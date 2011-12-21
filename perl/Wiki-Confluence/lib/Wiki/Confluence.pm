#
# $Id: Confluence.pm,v 1.4 2011/12/19 19:08:30 gonter Exp $
#

package Wiki::Confluence;

use 5.006;
use strict;
use warnings;

=head1 NAME

Wiki::Confluence - The great new Wiki::Confluence!

=head1 VERSION

Version 0.02

=cut

use XML::Twig;
use Data::Dumper;
$Data::Dumper::Indent= 1;

our $VERSION = '0.02';

=head1 SYNOPSIS

Process the XML dump of a Confluence Wiki.

    use Wiki::Confluence;

    my $cfl = new Wiki::Confluence ();
    ...

=head1 EXPORT

Currently, nothing gets exported.

=head1 METHODS

=cut

my %TODO_object_classes= map { $_ => 1 } qw(Space ReferralLink);

my %BodyContent_property_once= map { $_ => 1 } qw(bodyType content);
# properties should only present once, otherwise this should be a collection!

sub new
{
  my $class= shift;

  my $self=
  {
    '_stats_' => {},   # object class statistics
    '_pt_' => {        # "page tree"
      'active' => {},  # currently active pages, latest version
      'bc2p' => {},    # map bodyContent ID to Page ID
      'p2bc' => {},    # map Page ID to bodyContent ID
    },
  };
  bless $self, $class;

  $self->{'_TWIG_'}= new XML::Twig
  (
    'twig_roots' => # twig_handlers or twig_roots
    {
      'object' => sub { $self->hdl_object (@_); },
      # 'object' => \&hdl_object,
    },
    # 'PrettyPrint' => 'indented',
    'PrettyPrint' => 'record',
  );

  $self->set (@_);

  $self;
}

sub set
{
  my $self= shift;
  my %par= @_;

  my %res;
  my $call_parser= 0;
  foreach my $par (keys %par)
  {
    $res{$par}= $self->{$par};
    $self->{$par}= $par{$par};

    $call_parser= 1 if ($par eq 'entities');
  }

  $self->parse_entities () if ($call_parser);;

  (wantarray) ? %res : \%res;
}

sub get_array
{
  my $self= shift;
  my @par= @_;

  my @res;
  foreach my $par (@par)
  {
    push (@res, $self->{$par});
  }

  (wantarray) ? @res : \@res;
}

sub get_hash
{
  my $self= shift;
  my @par= @_;

  my %res;
  foreach my $par (@par)
  {
    $res{$par}= $self->{$par};
  }

  (wantarray) ? %res : \%res;
}

*get= *get_array;

# ======================================================================

=pod

=head2 $self->parse_entities (

=cut

sub parse_entities
{
  my $self= shift;
  my $fnm= shift;

  $self->{'entities'}= $fnm if (defined ($fnm));

  my $twig= $self->{'_TWIG_'};
  my $ent_fnm= $self->{'entities'};
  print "parse_entities: ent_fnm=[$ent_fnm]\n";
  $twig->parsefile ($ent_fnm);
}

sub stats
{
  my $self= shift;
  my $stats= $self->{'_stats_'};
  print "stats: ", Dumper ($stats);
}

=pod

=head2 $self->get_page ($page_id);

return our internal object describing one page in the page tree

=cut

sub get_page
{
  my $self= shift;
  my $p_id= shift;
  my %par= @_;

# print "get_page p_id=[$p_id]\n";
  my $p_obj= $self->{'_pt_'}->{'active'}->{$p_id};
  unless (defined ($p_obj))
  {
    $p_obj= $self->{'_pt_'}->{'active'}->{$p_id}= { 'id' => $p_id };
  }

  foreach my $par (keys %par)
  {
    $p_obj->{$par}= $par{$par};
  }

  $p_obj;
}

# ======================================================================

=head1 INTERNAL FUNCTIONS

=head2 $res= analyze_dummy ($elt)

generic function to analyze a tag structure and returns hash reference
describing it.

=cut

sub analyze_DUMMY
{
  my $fc= shift;

  my $res= {};

  print "--- 8< -----------------------------------\n";
  while (defined ($fc))
  {
    # print __LINE__, " analyze: fc=[$fc]\n";
    my $f_tag= $fc->tag ();
    print __LINE__, " f_tag=[$f_tag]\n";

    if ($f_tag eq 'id')
    {
      $res->{'id'}= $fc->text;
    }
    elsif ($f_tag eq 'property')
    {
      my $res_p= $res->{$f_tag};
      $res_p= $res->{$f_tag}= {} unless (defined ($res_p));

      my $c_type= $fc->{'att'}->{'name'};
      my $c_text= $fc->text;
      # push (@{$res->{$f_tag}->{$c_type}}, $c_text);

        if (exists ($res_p->{$c_type}))
	{
	  print "ATTN: BodyContent property [$c_type] already set!\n";
	}
        $res_p->{$c_type}= $c_text;
    }
    else
    {
      $res->{'_unknown_'}->{$f_tag}++;
      $fc->print; print "\n";
    }

    $fc= $fc->{'next_sibling'};
  }

  print __LINE__, " Page: ", Dumper ($res);
  print "--- >8 -----------------------------------\n\n";
  $res;
}

=head2 analyze_collecton ($elt)

returns an array reference describing the contents of a collection
tag structure.

=cut

sub analyze_collection
{
  my $fc= shift;

  my $res= [];

  while (defined ($fc))
  {
    my $f_tag= $fc->tag ();

    if ($f_tag eq 'element')
    {
      for (my $x= $fc->first_child; defined ($x); $x= $x->next_sibling)
      {
        my $f2_tag= $x->tag ();
	if ($f2_tag eq 'id')
	{
	  my $id= $x->text;
	  # print "id: $id\n";
	  push (@$res, $id);
        }
	else
	{
          print __LINE__, " ATTN: unexpected tag within collection=[$f2_tag]\n";
          $x->print; print "\n";
        }
      }
    }
    else
    {
      print __LINE__, " ATTN: f_tag=[$f_tag]\n";
      $fc->print; print "\n";
    }

    $fc= $fc->next_sibling;
  }

  # print __LINE__, " Coll: ", Dumper ($res);
  $res;
}

=head2 $res= analyze_Page

analyze the tag structure of a object element with class=Page

=cut

sub analyze_Page
{
  my $fc= shift;

  my $res= {};

  # print "--- 8< -----------------------------------\n";
  while (defined ($fc))
  {
    # print __LINE__, " analyze: fc=[$fc]\n";

    my $f_tag= $fc->tag ();
    # print __LINE__, " f_tag=[$f_tag]\n";

    if ($f_tag eq 'id')
    {
      $res->{'id'}= $fc->text;
    }
    elsif ($f_tag eq 'collection')
    {
      my $c_type= $fc->{'att'}->{'name'};
      $res->{$f_tag}->{$c_type}->{'_cnt_'}++;
      my $ids= analyze_collection ($fc->first_child);
      push (@{$res->{$f_tag}->{$c_type}->{'_ids_'}}, @$ids);
    }
    elsif ($f_tag eq 'property')
    {
      my $res_p= $res->{$f_tag};
      $res_p= $res->{$f_tag}= {} unless (defined ($res_p));

      my $c_type= $fc->{'att'}->{'name'};
      my $c_text= $fc->text;
      # push (@{$res->{$f_tag}->{$c_type}}, $c_text);

        if (exists ($res_p->{$c_type}))
	{
	  print "ATTN: BodyContent property [$c_type] already set!\n";
	}
        $res_p->{$c_type}= $c_text;
    }
    else
    {
      $res->{'_unknown_'}->{$f_tag}++;
      $fc->print; print "\n";
    }

    # print Dumper ($fc);
    $fc= $fc->{'next_sibling'};
  }

  # print __LINE__, " Page: ", Dumper ($res);
  # print "--- >8 -----------------------------------\n\n";
  $res;
}

=head2 $res= analyze_Page

analyze the tag structure of a object element with class=BodyContent

=cut

sub analyze_BodyContent
{
  my $fc= shift;

  my $res= {};

  # print "--- 8< -----------------------------------\n";
  while (defined ($fc))
  {
    my $f_tag= $fc->tag ();

    if ($f_tag eq 'id')
    {
      $res->{'id'}= $fc->text;
    }
    elsif ($f_tag eq 'property')
    {
      my $c_type= $fc->{'att'}->{'name'};
      my $c_text= $fc->text;

      my $res_p= $res->{$f_tag};
      $res_p= $res->{$f_tag}= {} unless (defined ($res_p));

      if ($c_type eq 'body')
      { # TODO: do something about this body...
        # delete ($res->{'property'}->{'body'});
        $res_p->{$c_type}++;
      }
      elsif (1 || exists ($BodyContent_property_once{$c_type}))
      { # these properties may be present only once
        if (exists ($res_p->{$c_type}))
	{
	  print "ATTN: BodyContent property [$c_type] already set!\n";
	}
        $res_p->{$c_type}= $c_text;
      }
      else
      {
        push (@{$res_p->{$c_type}}, $c_text);
      }

    }
    else
    {
      $res->{'_unknown_'}->{$f_tag}++;
      print __LINE__, " ATTN: f_tag=[$f_tag]\n";
      $fc->print; print "\n";
    }

    $fc= $fc->{'next_sibling'};
  }

  # print __LINE__, " BodyContent: ", Dumper ($res);
  # print "--- >8 -----------------------------------\n\n";
  $res;
}

=head2 $id= analyze_minimal

analyze the tag structure of an generic object element and return only
the ID.

=cut

sub analyze_minimal
{
  my $fc= shift;

  my $id;
  while (defined ($fc))
  {
    # print __LINE__, " analyze: fc=[$fc]\n";
    my $f_tag= $fc->tag ();
    # print __LINE__, " f_tag=[$f_tag]\n";

    if ($f_tag eq 'id')
    {
      $id= $fc->text;
    }

    $fc= $fc->{'next_sibling'};
  }

  $id;
}

=pod

=head2 $cfl->hdl_object ($twig, $elt)

twig parsing handler to process an object

=cut

sub hdl_object
{
  my $self= shift;
  my $twig= shift;
  my $elt= shift;

  my $cl= $elt->{'att'}->{'class'};
  $self->{'_stats_'}->{$cl}++;
  my $tag= $elt->tag ();

  # map { $elt->{$_}= '<deleted>' if (exists ($elt->{$_})); } qw(prev_sibling last_child);
  # map { delete ($elt->{$_}); } qw(parent);
  # print __LINE__, " object: elt=", Dumper ($elt->{'first_child'}), "\n"; exit;

  my $do_save= 1;
  my $do_dbg= 0; # if set, dump that stuff
  my ($d, $d_id);
  if ($cl eq 'Page')
  {
    $d= analyze_Page ($elt->{'first_child'});
    $d_id= $d->{'id'};
    my ($props, $colls)= map { $d->{$_} } qw (property collection);

    my $d_version= $props->{'version'};
    my $d_title= $props->{'title'};

    my $status= 'unknown';
    # find out, if this Page object is the latest or an older version

    my $x_hist= (exists ($colls->{'historicalVersions'})) ? $colls->{'historicalVersions'} : undef;
    my $x_orig= (exists ($props->{'originalVersion'}))    ? $props->{'originalVersion'} : undef;

    my $pt_obj;
    if ($x_hist && !$x_orig)
    {
      $status= 'latest';
      $pt_obj= $self->get_page ($d_id, 'title' => $d_title, 'version' => $d_version);
      $pt_obj->{'a_hist'}= $x_hist->{'_ids_'};
    }
    elsif ($x_orig && !$x_hist)
    {
      $status= 'old';
      $pt_obj= $self->get_page ($x_orig);
      $pt_obj->{'x_hist'}->{$d_id};
    }
    else
    {
      print "ATTN: unknown status!\n";
      $do_dbg++;
    }

    $d->{'_status_'}= $status;

    if (exists ($self->{'Page'}->{$d_id}))
    {
      print __LINE__, " ATTN: page id=[$d_id] exists!\n";
      $do_dbg++;
    }
    else
    {
      $self->{'Page'}->{$d_id}= $d;
    }

  }
  elsif ($cl eq 'BodyContent')
  {
    # $elt->print; print "\n";
    $d= analyze_BodyContent ($elt->{'first_child'});
    $d_id= $d->{'id'};
    my $p_id= $d->{'property'}->{'content'};

    # dunno, should we attach the content to an object?
    # my $pt_obj= $self->get_page ($p_id, 'BodyContent' => $d_id); ... that's not what we want
    $self->{'_pt_'}->{'p2bc'}->{$p_id}= $d_id;
    $self->{'_pt_'}->{'bc2p'}->{$d_id}= $p_id;

    # print __LINE__, " BodyContent: d_id=[$d_id]: ", Dumper ($d);
  }
  elsif ($cl eq 'BucketPropertySetItem')
  { # this object does not have an id!
    $do_save= 0;
    $self->{'_UNHANDLED_'}->{$cl}++;
  }
  # the following object classes should be fairly similar
  elsif ($cl eq 'Space')
  {
    $d= analyze_DUMMY ($elt->{'first_child'});
    $d_id= $d->{'id'};
    $self->{'_UNHANDLED_'}->{$cl}++;

    my $hp_id= $d->{'property'}->{'homePage'};
    $self->{'_pt_'}->{'homePage'}= $hp_id;

    print __LINE__, " $cl: d_id=[$d_id]\n";
    $elt->print; print "\n";

    # $self->{'_pt_'}->{$cl}= $d;
  }
  elsif ($cl eq 'SpaceDescription')
  {
    $d= analyze_DUMMY ($elt->{'first_child'});
    $d_id= $d->{'id'};
    $self->{'_UNHANDLED_'}->{$cl}++;

    print __LINE__, " $cl: d_id=[$d_id]\n";
    $elt->print; print "\n";

    # $self->{'_pt_'}->{$cl}= $d;
  }
  elsif (defined ($TODO_object_classes{$cl}))
  {
    # TODO: to be implemented!
    $self->{'_UNHANDLED_'}->{$cl}++;
    $d_id= analyze_minimal ($elt->{'first_child'});
  }
  else
  {
    # print __LINE__, " object: cl=[$cl] tag=[$tag]\n";
    # $elt->print; print "\n";
    $self->{'_UNHANDLED_'}->{$cl}++;
    $d_id= analyze_minimal ($elt->{'first_child'});
  }

  if ($do_dbg)
  {
    print __LINE__, "ATTN: do_dbg=$do_dbg [$cl]: ", Dumper ($d);
  }

  if ($do_save)
  {
    if (defined ($cl) && defined ($d_id))
    {
      &save ($elt, $cl, $d_id)
    }
    else
    {
      print __LINE__, " ATTN: can't save object: ";
DEBUG:
      $elt->print; print "\n";
    }
  }

  $elt->purge;
}

sub save
{
  my ($elt, $cl, $id)= @_;

  my $out_dir= join ('/', 'tmp', $cl);
  unless (-d $out_dir)
  {
    my $mkdir= "mkdir -p '$out_dir'";
    print ">>> $mkdir\n";
    system ($mkdir);
  }

  my $out_fnm= join ('/', $out_dir, $id);
  unless (-f $out_fnm)
  {
    print "saving [$out_fnm]\n";
# print "elt=[$elt]\n";
    # not available in XML::Twig VERSION 3.34, present in 3.39: $elt->print_to_file ($out_fnm);
    my $fh;

    if (open ($fh, '>' . $out_fnm))
    {
      $elt->print ($fh);
      close ($fh);
    }
    else
    {
      print "ATTN: cant write to [$out_fnm]\n";
    }

  }

  $out_fnm;
}

=head1 AUTHOR

Gerhard Gonter, C<< <ggonter at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-wiki-confluence
at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Wiki-Confluence>.
I will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Wiki::Confluence


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Wiki-Confluence>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Wiki-Confluence>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Wiki-Confluence>

=item * Search CPAN

L<http://search.cpan.org/dist/Wiki-Confluence/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Gerhard Gonter.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Wiki::Confluence
__END__
