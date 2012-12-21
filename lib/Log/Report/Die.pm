# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
use warnings;
use strict;

package Log::Report::Die;
use vars '$VERSION';
$VERSION = '0.992';

use base 'Exporter';

our @EXPORT = qw/die_decode/;

use Log::Report 'log-report';
use POSIX  qw/locale_h/;


sub die_decode($)
{   my @text   = split /\n/, $_[0];
    @text or return ();

    $text[0]   =~ s/\.$//;   # inconsequently used
    chomp $text[-1];

    my %opt    = (errno => $! + 0);
    my $err    = "$!";

    my $dietxt = $text[0];
    if($text[0] =~ s/ at (.+) line (\d+)$// )
    {   $opt{location} = [undef, $1, $2, undef];
    }
    elsif(@text > 1 && $text[1] =~ m/^\s*at (.+) line (\d+)\.?$/ )
    {   $opt{location} = [undef, $1, $2, undef];
        splice @text, 1, 1;
    }

    $text[0] =~ s/\s*[.:;]?\s*$err\s*$//
        or delete $opt{errno};

    my $msg = shift @text;
    length $msg or $msg = 'stopped';

    my @stack;
    foreach (@text)
    {   push @stack, [ $1, $2, $3 ]
            if m/^\s*(.*?)\s+called at (.*?) line (\d+)\s*$/;
    }
    $opt{stack}   = \@stack;
    $opt{classes} = [ 'perl', (@stack ? 'confess' : 'die') ];

    my $reason
      = @{$opt{stack}} ? ($opt{errno} ? 'ALERT' : 'PANIC')
      :                  ($opt{errno} ? 'FAULT' : 'ERROR');

    ($dietxt, \%opt, $reason, $msg);
}

1;
