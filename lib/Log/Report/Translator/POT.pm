# Copyrights 2007 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.02.
use warnings;
use strict;

package Log::Report::Translator::POT;
use vars '$VERSION';
$VERSION = '0.10';
use base 'Log::Report::Translator';

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Lexicon::Index;
use Log::Report::Lexicon::POTcompact;

use POSIX qw/:locale_h/;

my %indices;


sub translate($)
{   my ($self, $msg) = @_;

    my $domain = $msg->{_domain};
    my $locale = setlocale(LC_MESSAGES)
        or return $self->SUPER::translate($msg);

    my $pot    = exists $self->{pots}{$locale} ? $self->{pots}{$locale}
      : $self->load($domain, $locale);

    defined $pot
        or return $self->SUPER::translate($msg);

       $pot->msgstr($msg->{_msgid}, $msg->{_count})
    || return $self->SUPER::translate($msg);
}

sub load($$)
{   my ($self, $domain, $locale) = @_;

    foreach my $lex ($self->lexicons)
    {   my $potfn = $lex->find($domain, $locale);
        if($potfn)
        {   my $po = Log::Report::Lexicon::POTcompact
               ->read($potfn, charset => $self->charset);

            info __x "read pot-file {filename} for {domain} in {locale}"
              , filename => $potfn, domain => $domain, locale => $locale
                  if $domain ne 'log-report';  # avoid recursion

            return $self->{pots}{$locale} = $po;
        }

        # there are tables for domain, but not ours
        last if $lex->list($domain);
    }

    $self->{pots}{$locale} = undef
}

1;
