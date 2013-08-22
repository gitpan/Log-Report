# Copyrights 2007-2013 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.01.
use warnings;
use strict;

package Log::Report::Translator::POT;
use vars '$VERSION';
$VERSION = '0.994';

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


sub translate($;$)
{   my ($self, $msg, $lang) = @_;

    my $domain = $msg->{_domain};
    my $locale = $lang || setlocale(LC_MESSAGES)
        or return $self->SUPER::translate($msg, $lang);

    my $pot
      = exists $self->{pots}{$locale}
      ? $self->{pots}{$locale}
      : $self->load($domain, $locale);

    defined $pot
        or return $self->SUPER::translate($msg, $lang);

       $pot->msgstr($msg->{_msgid}, $msg->{_count})
    || $self->SUPER::translate($msg, $lang);   # default translation is 'none'
}

sub load($$)
{   my ($self, $domain, $locale) = @_;

    foreach my $lex ($self->lexicons)
    {   my $fn = $lex->find($domain, $locale);

        !$fn && $lex->list($domain)
            and last; # there are tables for domain, but not our lang

        $fn or next;

        my ($ext) = lc($fn) =~ m/\.(\w+)$/;
        my $class
          = $ext eq 'mo' ? 'Log::Report::Lexicon::MOTcompact'
          : $ext eq 'po' ? 'Log::Report::Lexicon::POTcompact'
          : error __x"unknown translation table extension '{ext}' in {filename}"
              , ext => $ext, filename => $fn;

        info __x"read table {filename} as {class} for {domain} in {locale}"
          , filename => $fn, class => $class, domain => $domain
          , locale => $locale
              if $domain ne 'log-report';  # avoid recursion

        eval "require $class" or panic $@;
 
        return $self->{pots}{$locale}
          = $class->read($fn, charset => $self->charset);
    }

    $self->{pots}{$locale} = undef;
}

1;
