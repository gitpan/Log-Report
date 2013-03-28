# Copyrights 2007-2013 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.01.
use warnings;
use strict;

package Log::Report::Dispatcher;
use vars '$VERSION';
$VERSION = '0.993';


use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Util qw/parse_locale expand_reasons %reason_code
  escape_chars/;

use POSIX      qw/strerror/;
use List::Util qw/sum/;
use Encode     qw/find_encoding FB_DEFAULT/;
use Devel::GlobalDestruction qw/in_global_destruction/;

eval { POSIX->import('locale_h') };
if($@)
{   no strict 'refs';
    *setlocale = sub { $_[1] }; *LC_ALL = sub { undef };
}

my %modes = (NORMAL => 0, VERBOSE => 1, ASSERT => 2, DEBUG => 3
  , 0 => 0, 1 => 1, 2 => 2, 3 => 3);
my @default_accept = ('NOTICE-', 'INFO-', 'ASSERT-', 'ALL');

my %predef_dispatchers = map { (uc($_) => __PACKAGE__.'::'.$_) }
   qw/File Perl Syslog Try Callback/;


sub new(@)
{   my ($class, $type, $name, %args) = @_;

    my $backend
      = $predef_dispatchers{$type}          ? $predef_dispatchers{$type}
      : $type->isa('Log::Dispatch::Output') ? __PACKAGE__.'::LogDispatch'
      : $type->isa('Log::Log4perl')         ? __PACKAGE__.'::Log4perl'
      : $type;

    eval "require $backend";
    $@ and alert "cannot use class $backend:\n$@";

    (bless {name => $name, type => $type, filters => []}, $backend)
       ->init(\%args);
}

my %format_reason = 
  ( LOWERCASE => sub { lc $_[0] }
  , UPPERCASE => sub { uc $_[0] }
  , UCFIRST   => sub { ucfirst lc $_[0] }
  , IGNORE    => sub { '' }
  );

my $default_mode = 'NORMAL';

sub init($)
{   my ($self, $args) = @_;

    my $mode = $self->_set_mode(delete $args->{mode} || $default_mode);
    $self->{locale} = delete $args->{locale};

    my $accept = delete $args->{accept} || $default_accept[$mode];
    $self->{needs}  = [ expand_reasons $accept ];

    my $f = delete $args->{format_reason} || 'LOWERCASE';
    $self->{format_reason} = ref $f eq 'CODE' ? $f : $format_reason{$f}
        or error __x"illegal format_reason '{format}' for dispatcher",
             format => $f;

    my $csenc;
    if(my $cs  = delete $args->{charset})
    {   my $enc = find_encoding $cs
            or error __x"Perl does not support charset {cs}", cs => $cs;
        $csenc = sub { no warnings 'utf8'; $enc->encode($_[0]) };
    }

    $self->{charset_enc} = $csenc || sub { $_[0] };
    $self;
}


sub close()
{   my $self = shift;
    $self->{closed}++ and return undef;
    $self->{disabled}++;
    $self;
}

sub DESTROY { in_global_destruction or shift->close }

#----------------------------


sub name {shift->{name}}


sub type() {shift->{type}}


sub mode() {shift->{mode}}

#Please use C<dispatcher mode => $MODE;>
sub defaultMode($) {$default_mode = $_[1]}

# only to be used via Log::Report::dispatcher(mode => ...)
# because requires re-investigating collective dispatcher needs
sub _set_mode($)
{   my $self = shift;
    my $mode = $self->{mode} = $modes{$_[0]};
    defined $mode
        or error __x"unknown run mode '{mode}'", mode => $_[0];

    $self->{needs}  = [ expand_reasons $default_accept[$mode] ];

    info __x"switching to run mode {mode}, accept {accept}"
       , mode => $mode, accept => $default_accept[$mode];

    $mode;
}

# only to be called from Log::Report::dispatcher()!!
# because requires re-investigating needs
sub _disabled($)
{   my $self = shift;
    @_ ? ($self->{disabled} = shift) : $self->{disabled};
}


sub isDisabled() {shift->{disabled}}
sub needs() { $_[0]->{disabled} ? () : @{$_[0]->{needs}} }


sub log($$$)
{   panic "method log() must be extended per back-end";
}


my %always_loc = map {($_ => 1)} qw/ASSERT PANIC/;
sub translate($$$)
{   my ($self, $opts, $reason, $msg) = @_;

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

    my $locale
      = defined $msg->msgid
      ? ($opts->{locale} || $self->{locale})      # translate whole
      : Log::Report->_setting($msg->domain, 'native_language');

    # not all implementations of setlocale() return the old value
    my $oldloc = setlocale(&LC_ALL);
    #setlocale(&LC_ALL, $locale || 'en_US');
    setlocale(&LC_ALL, $locale) if $locale;

    my $r = $self->{format_reason}->((__$reason)->toString);
    my $e = $opts->{errno} ? strerror($opts->{errno}) : undef;

    my $format
      = $r && $e ? N__"{reason}: {message}; {error}"
      : $r       ? N__"{reason}: {message}"
      : $e       ? N__"{message}; {error}"
      :            undef;

    my $text = defined $format
      ? __x($format, message => $msg->toString, reason => $r, error => $e
           )->toString
      : $msg->toString;
    $text .= "\n";

    if($show_loc)
    {   if(my $loc = $opts->{location} || $self->collectLocation)
        {   my ($pkg, $fn, $line, $sub) = @$loc;
            # pkg and sub are missing when decoded by ::Die
            $text .= " "
                  . __x( 'at {filename} line {line}'
                       , filename => $fn, line => $line)->toString
                  . "\n";
        }
    }

    if($show_stack)
    {   my $stack = $opts->{stack} ||= $self->collectStack;
        foreach (@$stack)
        {   $text .= $_->[0] . " "
              . __x( 'at {filename} line {line}'
                   , filename => $_->[1], line => $_->[2] )->toString
              . "\n";
        }
    }

    setlocale(&LC_ALL, $oldloc)
        if defined $oldloc;

    $self->{charset_enc}->($text);
}


sub collectStack($)
{   my ($thing, $max) = @_;

    my ($nest, $sub) = (1, undef);
    do { $sub = (caller $nest++)[3] }
    while(defined $sub && $sub ne 'Log::Report::report');
    defined $sub or $nest = 1;  # not found

    # skip syntax==SHORT routine entries
    $nest++ if defined $sub && $sub =~ m/^Log\:\:Report\:\:/;

    # special trick by Perl for Carp::Heavy: adds @DB::args
  { package DB;    # non-blank before package to avoid problem with OODoc

    my @stack;
    while(!defined $max || $max--)
    {   my ($pkg, $fn, $linenr, $sub) = caller $nest++;
        defined $pkg or last;

        my $line = $thing->stackTraceLine(call => $sub, params => \@DB::args);
        push @stack, [$line, $fn, $linenr];
    }

    \@stack;
  }
}


sub collectLocation()
{   my $thing = shift;
    my $nest  = 1;
    my @args;

    do {@args = caller $nest++}
    until $args[3] eq 'Log::Report::report';  # common entry point

    # skip syntax==SHORT routine entries
    @args = caller $nest++
        if +(caller $nest)[3] =~ m/^Log\:\:Report\:\:[^:]*$/;

    @args ? \@args : undef;
}


sub stackTraceLine(@)
{   my ($thing, %args) = @_;

    my $max       = $args{max_line}   ||= 500;
    my $abstract  = $args{abstract}   || 1;
    my $maxparams = $args{max_params} || 8;
    my @params    = @{$args{params}};
    my $call      = $args{call};

    my $obj = ref $params[0] && $call =~ m/^(.*\:\:)/ && UNIVERSAL::isa($params[0], $1)
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
    defined $param
        or return 'undef';

    $param = overload::StrVal($param)
        if ref $param;

    return $param   # int or float
        if $param =~ /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/;

    '"' . escape_chars($param) . '"';
}


1;
