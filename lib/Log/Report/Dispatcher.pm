# Copyrights 2007 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.00.
use warnings;
use strict;

package Log::Report::Dispatcher;
use vars '$VERSION';
$VERSION = '0.01';

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Util qw/parse_locale expand_reasons %reason_code
  escape_chars/;

use POSIX      qw/strerror locale_h/;
use List::Util qw/sum/;

my %modes = (NORMAL => 0, VERBOSE => 1, ASSERT => 2, TRACE => 3
  , 0 => 0, 1 => 1, 2 => 2, 3 => 3);
my @default_accept = ('NOTICE-', 'INFO-', 'ASSERT-', 'ALL');

my %predef_dispatchers = map { (uc($_) => __PACKAGE__.'::'.$_) }
   qw/File Syslog/;


sub new(@)
{   my ($class, $type, $name, %args) = @_;

    my $backend
      = $predef_dispatchers{$type} ? $predef_dispatchers{$type}
      : $type->isa('Log::Dispatch::Output')
      ? __PACKAGE__.'::LogDispatch'          # wrapper initializer
      : $type->isa('Log::Log4perl')
      ? __PACKAGE__.'::Log4perl'             # wrapper initializer
      : $type;

    eval "require $backend";
    $@ and alert "cannot use class $backend:\n$@";

    (bless {name => $name, type => $type, filters => []}, $backend)
       ->init(\%args);
}

sub init($)
{   my ($self, $args) = @_;
    my $mode = $self->_set_mode(delete $args->{mode} || 'NORMAL');

    $self->addFilter(delete $args->{filter});
    $self->{locale} = delete $args->{locale};

    my $accept = delete $args->{accept} || $default_accept[$mode];
    $self->{needs}  = [ expand_reasons $accept ];
    $self;
}


sub close()
{   my $self = shift;
    $self->{closed}++ and return undef;
    $self->{disabled}++;
    $self;
}

DESTROY() { shift->close }


sub name {shift->{name}}


sub type() {shift->{type}}


sub addFilter(@)
{   my $self = shift;

    foreach my $c (@_)
    {   defined $c or next;
        if(ref $c eq 'ARRAY')
        {   $self->addFilter(@$c);
            next;
        }

        ref $c eq 'CODE'
            or error __x"not a CODE reference: {param}", param => $c;

        push @{$self->{filters}}, $c;
    }
    @{$self->{filters}};
}


sub mode() {shift->{mode}}

# only to be used via Log::Report::dispatcher(mode => ...)
# because requires re-investigating needs
sub _set_mode($)
{   my $self = shift;
    my $mode = $self->{mode} = $modes{$_[0]};
    defined $mode
        or error __x"unknown run mode '{mode}'", mode => $_[0];

    info __x"switching to run mode {mode}", mode => $mode;
    $mode;
}

# only to be called from Log::Report::dispatcher()!!
# because requires re-investigating needs
sub _disable($)
{   my $self = shift;
    @_ ? ($self->{disabled} = shift) : $self->{disabled};
}


sub isDisabled() {shift->{disabled}}
sub needs() { $_[0]->{disabled} ? () : @{$_[0]->{needs}} }


sub log($$$)
{   panic "method log() must be extended per back-end";
}


my %always_loc = map {($_ => 1)} qw/ASSERT WARNING PANIC/;
sub translate($$$)
{   my ($self, $opts, $reason, $message) = @_;

    my $mode = $self->{mode};
    my $code = $reason_code{$reason}
        or panic "unknown reason '$reason'";

    my $show_loc
      = $always_loc{$reason}
     || ($mode==2 && $code >= $reason_code{WARNING})
     || ($mode==3 && $code >= $reason_code{MISTAKE});

    my $show_stack
      = $reason eq 'PANIC'
     || ($mode==2 && $code >= $reason_code{ALERT})
     || ($mode==3 && $code >= $reason_code{ERROR});

    my $translate = ref $message && $message->isa('Log::Report::Message');
    my $locale = $translate ? ($opts->{locale} || $self->{locale}) : 'en_US';
    my $loc    = defined $locale ? setlocale(LC_ALL, $locale) : undef;

    my $text;
    if($translate)
    {   $text  = (__$reason)->toString. ': '. $message->toString;
        $text .= ': ' . strerror($opts->{errno}) if $opts->{errno};
        $text .= "\n";
    }
    else
    {   $text   = "$reason: $message";
        $text  .= ': '. strerror($opts->{errno}) if $opts->{errno};
        $text  .= "\n";
    }

    if($show_stack)
    {   my $nest  = 1;
        my $sub;
        $sub = (caller $nest++)[3]
            while defined $sub && $sub ne 'Log::Report::report';

        # skip syntax==SHORT routine entries
        $nest++ if defined $sub && $sub =~ m/^Log\:\:Report\:\:/;
        my $stack = $self->collectStack($nest);

        foreach (@$stack)
        {   $text .= $_->[0] . " " .
              ( $translate
              ? __x( 'at {filename} line {line}'
                   , filename => $_->[1], line => $_->[2] )
              : "at $_->[1] line $_->[2]"
              ) . "\n";
        }
    }
    elsif($show_loc)
    {   my ($pkg, $fn, $line, $sub);
        my $nest = 1;
        do { ($pkg, $fn, $line, $sub) = caller $nest;
             $nest++;
        } until($sub eq 'Log::Report::report');

        # skip syntax==SHORT routine entries
        ($pkg, $fn, $line, $sub) = caller $nest++
            if((caller $nest)[3] =~ m/^Log\:\:Report\:\:/ );

        $text .= " " .
          ( $translate
          ? __x('at {filename} line {line}', filename => $fn, line => $line)
          : "at $fn line $line"
          ) . "\n";
    }

    setlocale(LC_ALL, $loc)
        if defined $loc;

    $text;
}


sub collectStack($;$)
{   my ($self, $nest, $max) = @_;

    # special trick by Perl for Carp::Heavy: adds @DB::args
  { package DB;    # non-blank before package to avoid problem with OODoc

    my @stack;
    while(!defined $max || $max--)
    {   my ($pkg, $fn, $linenr, $sub) = caller $nest++;
        defined $pkg or last;

        my $line = $self->stackTraceLine(call => $sub, params => \@DB::args);
        push @stack, [$line, $fn, $linenr];
    }

    \@stack;
  }
}


sub stackTraceLine(@)
{   my ($thing, %args) = @_;

    my $max       = $args{max_line}   ||= 500;
    my $abstract  = $args{abstract}   || 1;
    my $maxparams = $args{max_params} || 8;
    my @params    = @{$args{params}};
    my $call      = $args{call};

    my $obj = ref $params[0] && $call =~ m/^(.*\:\:)/ && $params[0]->isa($1)
      ? shift @params : undef;

    my $listtail  = '';
    if(@params > $maxparams)
    {   $listtail   = ', [' . (@params-$maxparams) . ' more]';
        $#params  = $maxparams -1;
    }

    $max        -= @params * 2 - length($listtail);  #  \( ( \,[ ] ){n-1} \)

    my $calling  = $thing->stackTraceCall(\%args, $abstract, $call, $obj);
    my @out      = map {$thing->stackTraceParam(\%args, $abstract, $_)} @params;
    my $total    = sum map {length $_} $calling, @out;

  ATTEMPT:
    while($total <= $max)
    {   $abstract++;
        last if $abstract > 2;  # later more levels

        foreach my $p (reverse 0..$#out)
        {   my $old  = $out[$p];
            $out[$p] = $thing->stackTraceParam(\%args, $abstract, $params[$p]);
            $total  -= length($old) - length($out[$p]);
            last ATTEMPT if $total <= $max;
        }

        my $old   = $calling;
        $calling  = $thing->stackTraceCall(\%args, $abstract, $call, $obj);
        $total   -= length($old) - length($calling);
    }

    $calling .'(' . join(', ',@out) . $listtail . ')';
}

# 1: My::Object(0x123141, "my string")
# 2: My::Object=HASH(0x1231451)
# 3: My::Object("my string")
# 4: My::Object()
#

sub stackTraceCall($$$;$)
{   my ($thing, $args, $abstract, $call, $obj) = @_;

    if(defined $obj)    # object oriented
    {   my ($pkg, $method) = $call =~ m/^(.*\:\:)(.*)/;
        return overload::StrVal($obj) . '->' . $call;
    }
    else                # imperative
    {   return $call;
    }
}

sub stackTraceParam($$$)
{   my ($thing, $args, $abstract, $param) = @_;

    return $param   # int or float
        if $param =~ /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/;

    return overload::StrVal($param)
        if ref $param;

    '"' . escape_chars($param) . '"';
}


1;
