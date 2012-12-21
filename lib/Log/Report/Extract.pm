# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.

use warnings;
use strict;

package Log::Report::Extract;
use vars '$VERSION';
$VERSION = '0.992';


use Log::Report 'log-report';
use Log::Report::Lexicon::Index ();
use Log::Report::Lexicon::POT   ();


sub new(@)
{   my $class = shift;
    (bless {}, $class)->init( {@_} );
}

sub init($)
{   my ($self, $args) = @_;
    my $lexi = $args->{lexicon}
        or error __"extractions require an explicit lexicon directory";

    -d $lexi or mkdir $lexi
        or fault __x"cannot create lexicon directory {dir}", dir => $lexi;

    $self->{LRE_index}   = Log::Report::Lexicon::Index->new($lexi);
    $self->{LRE_charset} = $args->{LRE_charset} || 'utf-8';
    $self->{LRE_domains} = {};
    $self;
}


sub index()   {shift->{LRE_index}}
sub charset() {shift->{LRE_charset}}
sub domains() {sort keys %{shift->{LRE_domains}}}
sub pots($)
{   my ($self, $domain) = @_;
    my $r = $self->{LRE_domains}{$domain};
    $r ? @$r : ();
}


sub process($@)
{   my ($self, $fn, %opts) = @_;
    panic "not implemented";
}


sub showStats(;$)
{   dispatcher needs => 'INFO'
        or return;

    my $self = shift;
    my @domains = @_ ? @_ : $self->domains;

    foreach my $domain (@domains)
    {   my $pots = $self->{LRE_domains}{$domain} or next;
        my ($msgids, $fuzzy, $inactive) = (0, 0, 0);

        foreach my $pot (@$pots)
        {   my $stats = $pot->stats;
            next unless $stats->{fuzzy} || $stats->{inactive};

            $msgids   = $stats->{msgids};
            next if $msgids == $stats->{fuzzy};   # ignore the template

            notice __x
                "{domain}: {fuzzy%3d} fuzzy, {inact%3d} inactive in {filename}"
              , domain => $domain, fuzzy => $stats->{fuzzy}
              , inact => $stats->{inactive}, filename => $pot->filename;

            $fuzzy    += $stats->{fuzzy};
            $inactive += $stats->{inactive};
        }

        if($fuzzy || $inactive)
        {   info __xn
"{domain}: one file with {ids} msgids, {f} fuzzy and {i} inactive translations"
, "{domain}: {_count} files each {ids} msgids, {f} fuzzy and {i} inactive translations in total"
              , scalar(@$pots), domain => $domain
              , f => $fuzzy, ids => $msgids, i => $inactive
        }
        else
        {   info __xn
                "{domain}: one file with {ids} msgids"
              , "{domain}: {_count} files with each {ids} msgids"
              , scalar(@$pots), domain => $domain, ids => $msgids;
        }
    }
}


sub write(;$)
{   my ($self, $domain) = @_;
    unless(defined $domain)  # write all
    {   $self->write($_) for $self->domains;
        return;
    }

    my $pots = delete $self->{LRE_domains}{$domain}
        or return;  # nothing found

    for my $pot (@$pots)
    {   $pot->updated;
        $pot->write;
    }

    $self;
}

sub DESTROY() {shift->write}

sub _reset($$)
{   my ($self, $domain, $fn) = @_;

    my $pots = $self->{LRE_domains}{$domain}
           ||= $self->_read_pots($domain);

    $_->removeReferencesTo($fn) for @$pots;
}

sub _read_pots($)
{   my ($self, $domain) = @_;

    my $index   = $self->index;
    my $charset = $self->charset;

    my @pots = map Log::Report::Lexicon::POT->read($_, charset=> $charset),
        $index->list($domain);

    trace __xn "found one pot file for domain {domain}"
             , "found {_count} pot files for domain {domain}"
             , @pots, domain => $domain;

    return \@pots
        if @pots;

    # new text-domain found, start template
    my $fn = $index->addFile("$domain.$charset.po");
    info __x"starting new textdomain {domain}, template in {filename}"
      , domain => $domain, filename => $fn;

    my $pot = Log::Report::Lexicon::POT->new
      ( textdomain => $domain
      , filename   => $fn
      , charset    => $charset
      , version    => 0.01
      );

    [ $pot ];
}


sub store($$$$;$)
{   my ($self, $domain, $fn, $linenr, $msgid, $plural) = @_;

    foreach my $pot ($self->pots($domain))
    {   if(my $po = $pot->msgid($msgid))
        {   $po->addReferences( ["$fn:$linenr"]);
            $po->plural($plural) if $plural;
            next;
        }

        my $format = $msgid =~ m/\{/ ? 'perl-brace' : 'perl';
        my $po = Log::Report::Lexicon::PO->new
          ( msgid        => $msgid
          , msgid_plural => $plural
          , fuzzy        => 1
          , format       => $format
          , references   => [ "$fn:$linenr" ]
          );

        $pot->add($po);
    }
}

1;
