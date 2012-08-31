# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
package Log::Report::Translator;
use vars '$VERSION';
$VERSION = '0.96';


use warnings;
use strict;

use File::Spec ();

use Log::Report 'log-report', syntax => 'SHORT';

use Log::Report::Lexicon::Index ();
use Log::Report::Message;

my %lexicons;

sub _filename_to_lexicon($);


sub new(@)
{   my $class = shift;
    (bless {}, $class)->init( {callerfn => (caller)[1], @_} );
}

sub init($)
{   my ($self, $args) = @_;
    my $lex = delete $args->{lexicons}
           || _filename_to_lexicon $args->{callerfn};

    my @lex;
    foreach my $lex (ref $lex eq 'ARRAY' ? @$lex : $lex)
    {   push @lex, $lexicons{$lex} ||=   # lexicon indexes are shared
            Log::Report::Lexicon::Index->new($lex);
    }
    $self->{lexicons} = \@lex;
    $self->{charset}  = $args->{charset} || 'utf-8';
    $self;
}

sub _filename_to_lexicon($)
{   my $fn = shift;
    $fn =~ s/\.pm$//;
    File::Spec->catdir($fn, 'messages');
}


sub lexicons() { @{shift->{lexicons}} }


sub charset() {shift->{charset}}


# this is called as last resort: if a translator cannot find
# any lexicon or has no matching language.
sub translate($)
{   my $msg = $_[1];

      defined $msg->{_count} && $msg->{_count} != 1
    ? $msg->{_plural}
    : $msg->{_msgid};
}


sub load($@) { undef }


sub TemplateToolkit($$$;$@)
{   my ($self, $domain, $lang, $msgid) = splice @_, 0, 4;
    my $plural = $msgid =~ s/\|(.*)// ? $1 : undef;
    my $args   = @_ && ref $_[-1] eq 'HASH' ? pop : {};

    my $count;
    if(defined $plural)
    {   @_==1 or $msgid .= " (ERROR: missing count for plural)";
        $count = shift;
    }
    else
    {   @_==0 or $msgid .= " (ERROR: only named parameters expected)";
    }

    my $msg = Log::Report::Message->new
        ( _msgid => $msgid, _plural => $plural, _count => $count
        , %$args, _expand => 1, _domain => $domain);

    $self->translate($msg, $lang);
}

1;
