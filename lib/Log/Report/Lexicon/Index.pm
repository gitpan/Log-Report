# Copyrights 2007 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.00.

package Log::Report::Lexicon::Index;
use vars '$VERSION';
$VERSION = '0.06';

use warnings;
use strict;

use File::Find  ();

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Util  qw/parse_locale/;


sub new($;@)
{   my $class = shift;
    bless {dir => @_}, $class;  # dir before first argument.
}


sub directory() {shift->{dir}}


sub index() 
{   my $self = shift;
    return $self->{index} if exists $self->{index};

    my $dir       = $self->directory;
    my $strip_dir = qr!\Q$dir/!;

    $self->{index} = {};
    File::Find::find
    ( +{ wanted   => sub
           { -f or return 1;
             (my $key = $_) =~ s/$strip_dir//;
             $self->addFile($key, $_);
             1;
           }
         , follow   => 1, no_chdir => 1
       } , $dir
    );

    $self->{index};
}


sub addFile($;$)
{   my ($self, $base, $abs) = @_;
    $abs ||= File::Spec->catfile($self->directory, $base);
    $base =~ s!\\!/!g;  # dos->unix
    $self->{index}{lc $base} = $abs;
}


# location to work-around platform dependent mutulations.
# may be extended with mo files as well.
sub _find($$) { $_[0]->{"$_[1].po"} }

sub find($$)
{   my $self   = shift;
    my $domain = lc shift;
    my $locale = lc shift;

    my $index = $self->index;
    keys %$index or return undef;

    my ($lang,$terr,$cs,$modif) = parse_locale $locale
        or error "illegal locale '{locale}', when looking for {domain}"
               , locale => $locale, domain => $domain;

    $terr  = defined $terr  ? '_'.$terr  : '';
    $cs    = defined $cs    ? '.'.$cs    : '';
    $modif = defined $modif ? '@'.$modif : '';

    (my $normcs = $cs) =~ s/[^a-z\d]//g;
    $normcs = "iso$normcs"
        if length $normcs && $normcs !~ /\D/;
    $normcs = '.'.$normcs
        if length $normcs;

    my $fn;

    for my $f ("/lc_messages/$domain", "/$domain")
    {   $fn
        ||= _find($index, "$lang$terr$cs$modif$f")
        ||  _find($index, "$lang$terr$normcs$modif$f")
        ||  _find($index, "$lang$terr$modif$f")
        ||  _find($index, "$lang$modif$f")
        ||  _find($index, "$lang$f");
    }

       $fn
    || _find($index, "$domain/$lang$terr$cs$modif")
    || _find($index, "$domain/$lang$terr$normcs$modif")
    || _find($index, "$domain/$lang$terr$modif")
    || _find($index, "$domain/$lang$modif")
    || _find($index, "$domain/$lang");
}


sub list($)
{   my $self   = shift;
    my $domain = lc shift;
    my $index  = $self->index;

    map { $index->{$_} }
       grep m! ^\Q$domain\E/ | \b\Q$domain\E[^/]*$ !x
          , keys %$index;
}


1;
