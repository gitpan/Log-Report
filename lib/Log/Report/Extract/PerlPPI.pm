# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.

use warnings;
use strict;

package Log::Report::Extract::PerlPPI;
use vars '$VERSION';
$VERSION = '0.992';

use base 'Log::Report::Extract';

use Log::Report 'log-report';
use PPI;

# See Log::Report translation markup functions
my %msgids =
 #         MSGIDs COUNT OPTS VARS SPLIT
 ( __   => [1,    0,    0,   0,   0]
 , __x  => [1,    0,    1,   1,   0]
 , __xn => [2,    1,    1,   1,   0]
 , __n  => [2,    1,    1,   0,   0]
 , N__  => [1,    0,    1,   1,   0]  # may be used with opts/vars
 , N__n => [2,    0,    1,   1,   0]  # idem
 , N__w => [1,    0,    0,   0,   1]
 );


sub process($@)
{   my ($self, $fn, %opts) = @_;

    my $charset = $opts{charset} || 'iso-8859-1';

    $charset eq 'iso-8859-1'
        or error __x"PPI only supports iso-8859-1 (latin-1) on the moment";

    my $doc = PPI::Document->new($fn, readonly => 1)
        or fault __x"cannot read from file {filename}", filename => $fn;

    my @childs = $doc->schildren;
    if(@childs==1 && ref $childs[0] eq 'PPI::Statement')
    {   info __x"no Perl in file {filename}", filename => $fn;
        return 0;
    }

    info __x"processing file {fn} in {charset}", fn=> $fn, charset => $charset;
    my ($pkg, $include, $domain, $msgs_found) = ('main', 0, undef, 0);

  NODE:
    foreach my $node ($doc->schildren)
    {   if($node->isa('PPI::Statement::Package'))
        {   $pkg     = $node->namespace;

            # special hack needed for module Log::Report itself
            if($pkg eq 'Log::Report')
            {   ($include, $domain) = (1, 'log-report');
                $self->_reset($domain, $fn);
            }
            else { ($include, $domain) = (0, undef) }
            next NODE;
        }

        if($node->isa('PPI::Statement::Include'))
        {   $node->type eq 'use' && $node->module eq 'Log::Report'
                or next NODE;

            $include++;
            my $dom = ($node->schildren)[2];
            $domain
               = $dom->isa('PPI::Token::Quote')            ? $dom->string
               : $dom->isa('PPI::Token::QuoteLike::Words') ? ($dom->literal)[0]
               : undef;

            $self->_reset($domain, $fn);
        }

        $node->find_any
         ( sub { # look for the special translation markers
                 $_[1]->isa('PPI::Token::Word') or return 0;

                 my $node = $_[1];
                 my $def  = $msgids{$node->content}  # get __() description
                     or return 0;

                 my @msgids = $self->_get($node, @$def)
                     or return 0;

                 my $line = $node->location->[0];
                 unless($domain)
                 {   mistake __x
                         "no text-domain for translatable at {fn} line {line}"
                        , fn => $fn, line => $line;
                     return 0;
                 }

                 if($def->[4])    # must split?  Bulk conversion strings
                 {   my @words = map {split} @msgids;
                     $self->store($domain, $fn, $line, $_) for @words;
                     $msgs_found += @words;
                 }
                 else
                 {   $self->store($domain, $fn, $line, @msgids);
                     $msgs_found += 1;
                 }

                 0;  # don't collect
               }
         );
    }

    $msgs_found;
}

sub _get($@)
{   my ($self, $node, $msgids, $count, $opts, $vars, $split) = @_;
    my $list_only = ($msgids > 1) || $count || $opts || $vars;
    my $expand    = $opts || $vars;

    my @msgids;
    my $first     = $node->snext_sibling;
    $first = $first->schild(0)
        if $first->isa('PPI::Structure::List');

    $first = $first->schild(0)
        if $first->isa('PPI::Statement::Expression');

    while(defined $first && $msgids > @msgids)
    {   my $msgid;
        my $next  = $first->snext_sibling;
        my $sep   = $next && $next->isa('PPI::Token::Operator') ? $next : '';
        my $line  = $first->location->[0];

        if($first->isa('PPI::Token::Quote'))
        {   last if $sep !~ m/^ (?: | \=\> | [,;:] ) $/x;
            $msgid = $first->string;

            if(  $first->isa("PPI::Token::Quote::Double")
              || $first->isa("PPI::Token::Quote::Interpolate"))
            {   mistake __x
                   "do not interpolate in msgid (found '{var}' in line {line})"
                   , var => $1, line => $line
                      if $first->string =~ m/(?<!\\)(\$\w+)/;

                # content string is uninterpreted, warnings to screen
                $msgid = eval "qq{$msgid}";

                error __x "string is incorrect at line {line}: {error}"
                   , line => $line, error => $@ if $@;
            }
        }
        elsif($first->isa('PPI::Token::Word'))
        {   last if $sep ne '=>';
            $msgid = $first->content;
        }
        else {last}

        mistake __x "new-line is added automatically (found in line {line})"
          , line => $line if $msgid =~ s/(?<!\\)\n$//;

        push @msgids, $msgid;
        last if $msgids==@msgids || !$sep;

        $first = $sep->snext_sibling;
    }

    @msgids;
}

1;
