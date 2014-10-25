# Copyrights 2007-2011 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
use warnings;
use strict;

package Log::Report::Translator::POT;
use vars '$VERSION';
$VERSION = '0.94';

use base 'Log::Report::Translator';

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Lexicon::Index;
use Log::Report::Lexicon::POTcompact;

use POSIX qw/:locale_h/;

my %indices;

# Work-around for missing LC_MESSAGES on old Perls and Windows
{ no warnings;
  eval "&LC_MESSAGES";
  *LC_MESSAGES = sub(){5} if $@;
}


sub translate($)
{   my ($self, $msg) = @_;

    my $domain = $msg->{_domain};
    my $locale = setlocale(LC_MESSAGES)
        or return $self->SUPER::translate($msg);

    my $pot
      = exists $self->{pots}{$locale}
      ? $self->{pots}{$locale}
      : $self->load($domain, $locale);

    defined $pot
        or return $self->SUPER::translate($msg);

       $pot->msgstr($msg->{_msgid}, $msg->{_count})
    || $self->SUPER::translate($msg);   # default translation is 'none'
}

sub load($$)
{   my ($self, $domain, $locale) = @_;

    foreach my $lex ($self->lexicons)
    {   my $potfn = $lex->find($domain, $locale);

        !$potfn && $lex->list($domain)
            and last; # there are tables for domain, but not our lang

        $potfn or next;

        my $po = Log::Report::Lexicon::POTcompact
           ->read($potfn, charset => $self->charset);

        info __x "read pot-file {filename} for {domain} in {locale}"
          , filename => $potfn, domain => $domain, locale => $locale
              if $domain ne 'log-report';  # avoid recursion

        return $self->{pots}{$locale} = $po;
    }

    $self->{pots}{$locale} = undef;
}

1;
