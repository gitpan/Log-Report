# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.

use warnings;
use strict;

package Log::Report::Extract::Template;
use vars '$VERSION';
$VERSION = '0.95';

use base 'Log::Report::Extract';

use Log::Report 'log-report';


sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{LRET_domain}  = $args->{domain}
        or error "template extract requires explicit domain";

    $self->{LRET_pattern} = $self->_pattern($args->{pattern});
    $self;
}


sub domain()  {shift->{LRET_domain}}
sub pattern() {shift->{LRET_pattern}}


sub process($@)
{   my ($self, $fn, %opts) = @_;

    my $charset = $opts{charset} || 'utf-8';
    info __x"processing file {fn} in {charset}", fn=> $fn, charset => $charset;

    # Slurp the whole file
    local *IN;
    open IN, "<:encoding($charset)", $fn
        or fault __x"cannot read template from {fn}", fn => $fn;

    undef $/;
    my $text = <IN>;
    close IN;

    my $domain  = $self->domain;
    $self->_reset($domain, $fn);

    my $pattern = $self->_pattern($opts{pattern}) || $self->pattern
        or error __"need pattern to scan for, either via new() or process()";

    # Split the whole file on the pattern in four fragments per match:
    #       (text, leading, needed trailing, text, leading, ...)
    # f.i.  ('', '[% loc("', 'some-msgid', '", params) %]', ' more text')
    my @frags  = split $pattern, $text;

    my $linenr     = 1;
    my $msgs_found = 0;

    while(@frags > 4)
    {   $linenr += ($frags[0] =~ tr/\n//)   # text
                +  ($frags[1] =~ tr/\n//);  # leading
        (my $msgid = $frags[2]) =~ s/^(['"]*)(.*?)\1/$2/;
        $self->store($domain, $fn, $linenr, $msgid);
        $msgs_found++;
        $linenr += ($frags[2] =~ tr/\n//)
                +  ($frags[3] =~ tr/\n//);
        splice @frags, 0, 4;
    }

    $msgs_found;
}

#----------------------------------------------------

sub _pattern($)
{   my ($self, $pattern) = @_;

    return $pattern
        if !defined $pattern || ref $pattern eq 'Regexp';

    if($pattern =~ m/^TT([12])-(\w+)$/)
    {    # Recognized is Template::Toolkit 2
         my ($level, $function) = ($1, $2);
         my ($open, $close) = $level==1 ? ('[\[%]%', '%[\]%]') : ('\[%', '%\]');

         return qr/( $open \s* \Q$function\E \s* \( \s* ) # leading
                   ( "[^"\s]*" | '[^']*' )                # msgid
                   ( .*?                                  # params
                     $close )                             # ending
                  /xs;
    }

    error __x"scan pattern `{pattern}' not recognized", pattern => $pattern;
}

1;
