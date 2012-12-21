# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
package Log::Report::Translator;
use vars '$VERSION';
$VERSION = '0.992';


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
    my $lex = delete $args->{lexicons} || delete $args->{lexicon}
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

1;
