# Copyrights 2007-2008 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.03.

use warnings;
use strict;

package Log::Report::Lexicon::PO;
use vars '$VERSION';
$VERSION = '0.15';

use Log::Report 'log-report', syntax => 'SHORT';

# mixins
use Log::Report::Lexicon::POTcompact qw/_escape _unescape/;


sub new(@)
{   my $class = shift;
    (bless {}, $class)->init( {@_} );
}

sub init($)
{   my ($self, $args) = @_;
    defined($self->{msgid} = delete $args->{msgid})
       or error "no msgid defined for PO";

    $self->{plural} = delete $args->{msgid_plural};
    my $str         = delete $args->{msgstr};
    $self->{msgstr}
      = !defined $str       ? []
      : ref $str eq 'ARRAY' ? $str
      :                       [$str];

    $self->addComment(delete $args->{comment});
    $self->addAutomatic(delete $args->{automatic});
    $self->fuzzy(delete $args->{fuzzy});

    $self->{refs}   = {};
    $self->addReferences(delete $args->{references})
        if defined $args->{references};

    $self;
}


sub msgid() {shift->{msgid}}


sub plural(;$)
{   my $self = shift;
    @_ ? ($self->{plural} = shift) : $self->{plural};
}


sub msgstr($;$)
{   my $self = shift;
    return $self->{msgstr}[shift || 0]
       if @_ < 2;

    my ($nr, $string) = @_;
    $self->{msgstr}[$nr] = $string;
}


sub comment(@)
{   my $self = shift;
    @_ or return $self->{comment};
    $self->{comment} = '';
    $self->addComment(@_);
}


sub addComment(@)
{   my $self    = shift;
    my $comment = $self->{comment};
    foreach my $line (ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_)
    {   defined $line or next;
        $line =~ s/[\r\n]+/\n/;  # cleanup line-endings
        $comment .= $line;
    }

    # be sure there is a \n at the end
    $comment =~ s/\n?\z/\n/ if defined $comment;
    $self->{comment} = $comment;
}


sub automatic(@)
{   my $self = shift;
    @_ or return $self->{automatic};
    $self->{automatic} = '';
    $self->addAutomatic(@_);
}


sub addAutomatic(@)
{   my $self = shift;
    my $auto = $self->{automatic};
    foreach my $line (ref $_[0] eq 'ARRAY' ? @{$_[0]} : @_)
    {   defined $line or next;
        $line =~ s/[\r\n]+/\n/;  # cleanup line-endings
        $auto .= $line;
    }

    $auto =~ s/\n?\z/\n/ if defined $auto; # be sure there is a \n at the end
    $self->{automatic} = $auto;
}


sub references(@)
{   my $self = shift;
    if(@_)
    {   $self->{refs} = {};
        $self->addReferences(@_);
    }

    keys %{$self->{refs}};
}


sub addReferences(@)
{   my $self = shift;
    my $refs = $self->{refs} ||= {};
    @_ or return $refs;

    $refs->{$_}++
       for @_ > 1               ? @_       # list
         : ref $_[0] eq 'ARRAY' ? @{$_[0]} # array
         : split " ",$_[0];                # scalar
    $refs;
}


sub removeReferencesTo($)
{   my $refs  = $_[0]->{refs};
    my $match = qr/^\Q$_[1]\E\:\d+$/;
    $_ =~ $match && delete $refs->{$_}
        for keys %$refs;

    scalar keys %$refs;
}


sub isActive() { $_[0]->{msgid} eq '' || keys %{$_[0]->{refs}} }


sub fuzzy(;$) {my $self = shift; @_ ? $self->{fuzzy} = shift : $self->{fuzzy}}


sub format(@)
{   my $format = shift->{format};
    return $format->{ (shift) }
        if @_==1 && !ref $_[0];  # language

    my @pairs = @_ > 1 ? @_ : ref $_[0] eq 'ARRAY' ? @{$_[0]} : %{$_[0]};
    while(@pairs)
    {   my($k, $v) = (shift @pairs, shift @pairs);
        $format->{$k} = $v;
    }
    $format;
}


sub addFlags($)
{   my $self  = shift;
    local $_  = shift;
    my $where = shift;

    s/^\s+//;
    s/\s*$//;
    foreach my $flag (split /\s*\,\s*/)
    {      if($flag eq 'fuzzy') { $self->fuzzy(1) }
        elsif($flag =~ m/^no-(.*)-format$/) { $self->format($1, 0) }
        elsif($flag =~ m/^(.*)-format$/)    { $self->format($1, 1) }
        else
        {   warning __x"unknown flag {flag} ignored", flag => $flag;
        }
    }
    $_;
}

sub fromText($$)
{   my $class = shift;
    my @lines = split /[\r\n]+/, shift;
    my $where = shift || ' unkown location';

    my $self  = bless {}, $class;

    # translations which are not used anymore are escaped with #~
    # however, we just say: no references found.
    s/^\#\~\s+// for @lines;

    my $last;
    foreach (@lines)
    {   chomp;
        if( s/^\#(.)\s?// )
        {      if($1 =~ /\s/) { $self->addComment($_)    }
            elsif($1 eq '.' ) { $self->addAutomatic($_)  }
            elsif($1 eq ':' ) { $self->addReferences($_) }
            elsif($1 eq ',' ) { $self->addFlags($_)      }
            else
            {   warning __x"unknown comment type '{cmd}' at {where}"
                  , cmd => "#$1", where => $where;
            }
            undef $last;
        }
        elsif( s/^\s*(\w+)\s+// )
        {   my $cmd    = $1;
            my $string = _unescape($_,$where);

            if($cmd eq 'msgid')
            {   $self->{msgid} = $string;
                $last = \($self->{msgid});
            }
            elsif($cmd eq 'msgid_plural')
            {   $self->{plural} = $string;
                $last = \($self->{plural});
            }
            elsif($cmd eq 'msgstr')
            {   $self->{msgstr} = [$string];
                $last = \($self->{msgstr}[0]);
            }
            else
            {   warning __x"do not understand command '{cmd}' at {where}"
                  , cmd => $cmd, where => $where;
                undef $last;
            }
        }
        elsif( s/^\s*msgstr\[(\d+)\]\s*// )
        {   my $nr = $1;
            $self->{msgstr}[$nr] = _unescape($_,$where);
        }
        elsif( m/^\s*\"/ )
        {   if(defined $last) { $$last .= _unescape($_,$where) }
            else
            {   warning __x"quoted line is not a continuation at {where}"
                 , where => $where;
            }
        }
        else
        {   warning __x"do not understand line at {where}:\n  {line}"
              , where => $where, line => $_;
        }
    }

    warning __x"no msgid in block {where}", where => $where
        unless defined $self->{msgid};

    $self;
}


sub toString(@)
{   my ($self, %args) = @_;
    my $nplurals = $args{nr_plurals};
    my @text;

    my $comment = $self->comment;
    if(defined $comment && length $comment)
    {   $comment =~ s/^/#  /gm;
        push @text, $comment;
    }

    my $auto = $self->automatic;
    if(defined $auto && length $auto)
    {   $auto =~ s/^/#. /gm;
        push @text, $auto;
    }

    my @refs   = sort $self->references;
    my $msgid  = $self->{msgid} || '';
    my $active = $msgid eq '' || @refs ? '' : '#~ ';

    while(@refs)
    {   my $line = '#:';
        $line .= ' '.shift @refs
            while @refs && length($line) + length($refs[0]) < 80;
        push @text, "$line\n";
    }

    my @flags = $self->{fuzzy} ? 'fuzzy' : ();

    push @flags, ($self->{format}{$_} ? '' : 'no-') . $_ . '-format'
        for sort keys  %{$self->{format}};

    push @text, "#, ". join(", ", @flags) . "\n"
        if @flags;

    push @text, "${active}msgid "._escape($msgid, "\n$active")."\n"; 

    my @msgstr = @{$self->{msgstr} || []};
    my $plural = $self->{plural};
    if(defined $plural)
    {   push @text, "${active}msgid_plural "
                  . _escape($plural, "\n$active")
                  . "\n";

        push @msgstr, ''
            while defined $nplurals && @msgstr < $nplurals;

        if(defined $nplurals && @msgstr > $nplurals)
        {   warning __x"too many plurals for '{msgid}'", msgid => $msgid;
            $#msgstr = $nplurals -1;
        }

        $nplurals ||= 2;
        for(my $nr = 0; $nr < $nplurals; $nr++)
        {   push @text, "${active}msgstr[$nr] "
                        . _escape($msgstr[$nr], "\n$active") . "\n";
        }
    }
    else
    {   warning __x"no plurals for '{msgid}'", msgid => $msgid
            if @msgstr > 1;

        push @text, "${active}msgstr "
                  . _escape($msgstr[0], "\n$active")
                  . "\n";
    }

    join '', @text;
}


sub unused()
{   my $self = shift;
    ! $self->references && ! $self->msgstr(0);
}

1;
