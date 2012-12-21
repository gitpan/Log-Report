# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
package Log::Report::Lexicon::POTcompact;
use vars '$VERSION';
$VERSION = '0.992';

use base 'Log::Report::Lexicon::Table';

use warnings;
use strict;

use Log::Report        'log-report';
use Log::Report::Util  qw/escape_chars unescape_chars/;

sub _unescape($$);
sub _escape($$);


sub read($@)
{   my ($class, $fn, %args) = @_;

    my $self    = bless {}, $class;

    my $charset = $args{charset}
        or error __x"charset parameter required for {fn}", fn => $fn;

    open my $fh, "<:encoding($charset)", $fn
        or fault __x"cannot read in {cs} from file {fn}"
             , cs => $charset, fn => $fn;

    # Speed!
    my ($last, $msgctxt, $msgid, @msgstr);
 LINE:
    while(my $line = $fh->getline)
    {   next if substr($line, 0, 1) eq '#';

        if($line =~ m/^\s*$/)  # blank line starts new
        {   if(@msgstr)
            {   $self->{index}{$msgid} = @msgstr > 1 ? [@msgstr] : $msgstr[0];
                ($msgid, @msgstr) = ();
            }
            next LINE;
        }

        if($line =~ s/^msgctxt\s+//)
        {   undef $last;   # ignore context records
        }
        elsif($line =~ s/^msgid\s+//)
        {   $msgid  = _unescape $line, $fn;
            $last   = \$msgid;
        }
        elsif($line =~ s/^msgstr\[(\d+)\]\s*//)
        {   $last   = \($msgstr[$1] = _unescape $line, $fn);
        }
        elsif($line =~ s/^msgstr\s+//)
        {   $msgstr[0] = _unescape $line, $fn;
            $last   = \$msgstr[0];
        }
        elsif($last && $line =~ m/^\s*\"/)
        {   $$last .= _unescape $line, $fn;
        }
    }

    $self->{index}{$msgid} = (@msgstr > 1 ? \@msgstr : $msgstr[0])
        if @msgstr;   # don't forget the last

    close $fh
        or failure __x"failed reading from file {fn}", fn => $fn;

    $self->{filename} = $fn;
    $self->setupPluralAlgorithm;
    $self;
}


sub index()     {shift->{index}}
sub filename()  {shift->{filename}}


sub msgid($) { $_[0]->{index}{$_[1]} }


# speed!!!
sub msgstr($;$)
{   my $po   = $_[0]->{index}{$_[1]}
        or return undef;

    ref $po   # no plurals defined
        or return $po;

       $po->[$_[0]->{algo}->(defined $_[2] ? $_[2] : 1)]
    || $po->[$_[0]->{algo}->(1)];
}

#
### internal helper routines, shared with ::PO.pm and ::POT.pm
#

sub _unescape($$)
{   unless( $_[0] =~ m/^\s*\"(.*)\"\s*$/ )
    {   warning __x"string '{text}' not between quotes at {location}"
           , text => $_[0], location => $_[1];
        return $_[0];
    }
    unescape_chars $1;
}

sub _escape($$)
{   my @escaped = map { '"' . escape_chars($_) . '"' }
        defined $_[0] && length $_[0] ? split(/(?<=\n)/, $_[0]) : '';

    unshift @escaped, '""' if @escaped > 1;
    join $_[1], @escaped;
}

1;
