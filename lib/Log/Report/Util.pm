# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.

use warnings;
use strict;

package Log::Report::Util;
use vars '$VERSION';
$VERSION = '0.992';

use base 'Exporter';

our @EXPORT = qw/@reasons %reason_code
  parse_locale expand_reasons escape_chars unescape_chars/;

use Log::Report 'log-report';

# ordered!
our @reasons = N__w('TRACE ASSERT INFO NOTICE WARNING
    MISTAKE ERROR FAULT ALERT FAILURE PANIC');
our %reason_code; { my $i=1; %reason_code = map { ($_ => $i++) } @reasons }

my @user    = qw/MISTAKE ERROR/;
my @program = qw/TRACE ASSERT INFO NOTICE WARNING PANIC/;
my @system  = qw/FAULT ALERT FAILURE/;


sub parse_locale($)
{   my $locale = shift;
    defined $locale && length $locale
        or return;

    if($locale !~
      m/^ ([a-z_]+)
          (?: \. ([\w-]+) )?  # codeset
          (?: \@ (\S+) )?     # modifier
        $/ix)
    {   # Windows Finnish_Finland.1252?
        $locale =~ s/.*\.//;
        return wantarray ? ($locale) : { language => $locale };
    }

    my ($lang, $codeset, $modifier) = ($1, $2, $3);

    my @subtags  = split /[_-]/, $lang;
    my $primary  = lc shift @subtags;

    my $language
      = $primary eq 'c'             ? 'C'
      : $primary eq 'posix'         ? 'POSIX'
      : $primary =~ m/^[a-z]{2,3}$/ ? $primary            # ISO639-1 and -2
      : $primary eq 'i' && @subtags ? lc(shift @subtags)  # IANA
      : $primary eq 'x' && @subtags ? lc(shift @subtags)  # Private
      : error __x"unknown locale language in locale `{locale}'"
           , locale => $locale;

    my $script;
    $script = ucfirst lc shift @subtags
        if @subtags > 1 && length $subtags[0] > 3;

    my $territory = @subtags ? uc(shift @subtags) : undef;

    return ($language, $territory, $codeset, $modifier)
        if wantarray;

    +{ language  => $language
     , script    => $script
     , territory => $territory
     , codeset   => $codeset
     , modifier  => $modifier
     , variant   => join('-', @subtags)
     };
}


sub expand_reasons($)
{   my $reasons = shift;
    my %r;
    foreach my $r (split m/\,/, $reasons)
    {   if($r =~ m/^([a-z]*)\-([a-z]*)/i )
        {   my $begin = $reason_code{$1 || 'TRACE'};
            my $end   = $reason_code{$2 || 'PANIC'};
            $begin && $end
                or error __x "unknown reason {which} in '{reasons}'"
                     , which => ($begin ? $2 : $1), reasons => $reasons;

            error __x"reason '{begin}' more serious than '{end}' in '{reasons}"
              , begin => $1, end => $2, reasons => $reasons
                 if $begin >= $end;

            $r{$_}++ for $begin..$end;
        }
        elsif($reason_code{$r}) { $r{$reason_code{$r}}++ }
        elsif($r eq 'USER')     { $r{$reason_code{$_}}++ for @user    }
        elsif($r eq 'PROGRAM')  { $r{$reason_code{$_}}++ for @program }
        elsif($r eq 'SYSTEM')   { $r{$reason_code{$_}}++ for @system  }
        elsif($r eq 'ALL')      { $r{$reason_code{$_}}++ for @reasons }
        else
        {   error __x"unknown reason {which} in '{reasons}'"
              , which => $r, reasons => $reasons;
        }
    }
    (undef, @reasons)[sort {$a <=> $b} keys %r];
}


my %unescape
 = ( '\a' => "\a", '\b' => "\b", '\f' => "\f", '\n' => "\n"
   , '\r' => "\r", '\t' => "\t", '\"' => '"', '\\\\' => '\\'
   , '\e' =>  "\x1b", '\v' => "\x0b"
   );
my %escape   = reverse %unescape;

sub escape_chars($)
{   my $str = shift;
    $str =~ s/([\x00-\x1F"\\])/$escape{$1} || '?'/ge;
    $str;
}

sub unescape_chars($)
{   my $str = shift;
    $str =~ s/(\\.)/$unescape{$1} || $1/ge;
    $str;
}

1;
