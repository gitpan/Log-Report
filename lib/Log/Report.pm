# Copyrights 2007 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.00.

use warnings;
use strict;

package Log::Report;
use vars '$VERSION';
$VERSION = '0.04';
use base 'Exporter';

# domain 'log-report' via work-arounds:
#     Log::Report cannot do "use Log::Report"

my @make_msg   = qw/__ __x __n __nx __xn N__ N__n N__w/;
my @functions  = qw/report dispatcher try/;
my @reason_functions = qw/trace assert info notice warning
   mistake error fault alert failure panic/;

our @EXPORT_OK = (@make_msg, @functions, @reason_functions);

require Log::Report::Util;
require Log::Report::Message;
require Log::Report::Dispatcher;

# See chapter Run modes
my %is_reason = map {($_=>1)} @Log::Report::Util::reasons;
my %is_fatal  = map {($_=>1)} qw/ERROR FAULT FAILURE PANIC/;
my %use_errno = map {($_=>1)} qw/WARNING FAULT ALERT FAILURE/;

sub _whats_needed(); sub dispatcher($@);
sub trace(@); sub assert(@); sub info(@); sub notice(@); sub warning(@);
sub mistake(@); sub error(@); sub fault(@); sub alert(@); sub failure(@);
sub panic(@);
sub __($); sub __x($@); sub __n($$$@); sub __nx($$$@); sub __xn($$$@);
sub N__($); sub N__n($$); sub N__w(@);

require Log::Report::Translator::POT;
my %translator =
 ( 'log-report' => Log::Report::Translator::POT->new(charset => 'utf-8')
 , rescue       => Log::Report::Translator->new
 );

my $reporter;
my %domain_start;

dispatcher FILE => stderr =>
   to => \*STDERR, accept => 'NOTICE-'
      if -t STDERR;


sub report($@)
{   my $opts   = ref $_[0] eq 'HASH' ? +{ %{ (shift) } } : {};
    @_ or return ();

    my $reason = shift;
    $is_reason{$reason}
       or error __"Token '{token}' not recognized as reason"
            , token => $reason;

    my @disp;
    keys %{$reporter->{dispatchers}}
        or return;

    $opts->{errno} ||= $!+0  # want copy!
        if $use_errno{$reason};

    my $stop = $is_fatal{$reason};

    # exit when needed, even when message doesn't go anywhere.
    my $disp = $reporter->{needs}{$reason};
    unless($disp)
    {   if($stop) { $! = $opts->{errno} || 1; die }
        return ();
    }

    # explicit destination
    if(my $to = delete $opts->{to})
    {   foreach my $t (ref $to eq 'ARRAY' ? @$to : $to)
        {   push @disp, grep {$_->name eq $t} @$disp;
        }
    }
    else { @disp = @$disp }

    # join does not respect overload of '.'
    my $message = shift;
    $message   .= shift while @_;

    # untranslated message into object
    ref $message && $message->isa('Log::Report::Message')
        or $message = Log::Report::Message->new(_prepend => $message);

    if($reporter->{filters})
    {
      DISPATCHER:
        foreach my $disp (@disp)
        {   my ($r, $m) = ($reason, $message);
            foreach my $filter ( @{$reporter->{filters}} )
            {   next if keys %{$filter->[1]} && !$filter->[1]{$disp->name};
                ($r, $m) = $filter->[0]->($disp, $opts, $r, $m);
                $r or next DISPATCHER;
            }
            $disp->log($opts, $reason, $message);
        }
    }
    else
    {   $_->log($opts, $reason, $message)
            for @disp;
    }

    if($stop)
    {   $! = $opts->{errno} || 1;
        die;
    }

    @disp;
}


sub dispatcher($@)
{   if($_[0] !~ m/^(?:close|find|list|disable|enable|mode|needs|filter)$/)
    {   my $disp = Log::Report::Dispatcher->new(@_);

        # old dispatcher with same name will be closed in DESTROY
        $reporter->{dispatchers}{$disp->name} = $disp;
        _whats_needed;
        return ($disp);
    }

    my $command = shift;
    if($command eq 'list')
    {   mistake __"the 'list' sub-command doesn't expect additional parameters"
           if @_;
        return values %{$reporter->{dispatchers}};
    }
    if($command eq 'needs')
    {   my $reason = shift || 'undef';
        error __"the 'needs' sub-command parameter '{reason}' is not a reason"
            unless $is_reason{$reason};
        my $disp = $reporter->{needs}{$reason};
        return $disp ? @$disp : ();
    }
    if($command eq 'filter')
    {   my $code = shift;
        error __"the 'filter' sub-command needs a CODE reference"
            unless ref $code eq 'CODE';
        my %names = map { ($_ => 1) } @_;
        push @{$reporter->{filters}}, [ $code, \%names ];
        return ();
    }

    my $mode    = $command eq 'mode' ? shift : undef;

    error __"in SCALAR context, only one dispatcher name accepted"
        if @_ > 1 && !wantarray && defined wantarray;

    my @dispatchers = grep defined, @{$reporter->{dispatchers}}{@_};
    if($command eq 'close')
    {   delete @{$reporter->{dispatchers}}{@_};
        $_->close for @dispatchers;
    }
    elsif($command eq 'enable')  { $_->_disabled(0) for @dispatchers }
    elsif($command eq 'disable') { $_->_disabled(1) for @dispatchers }
    elsif($command eq 'mode'){ $_->_set_mode($mode) for @dispatchers }

    # find does require reinventarization
    _whats_needed unless $command eq 'find';

    wantarray ? @dispatchers : $dispatchers[0];
}

END { $_->close for values %{$reporter->{dispatchers}} }

# _whats_needed
# Investigate from all dispatchers which reasons will need to be
# passed on.   After dispatchers are added, enabled, or disabled,
# this method shall be called to re-investigate the back-ends.

sub _whats_needed()
{   my %needs;
    foreach my $disp (values %{$reporter->{dispatchers}})
    {   push @{$needs{$_}}, $disp for $disp->needs;
    }
    $reporter->{needs} = \%needs;
}


sub try(&@)
{   my $code = shift;
    local $reporter->{dispatchers} = undef;
    local $reporter->{needs};

    my $disp = dispatcher TRY => 'try', @_;

    eval { $code->() };
    $disp->died($@);

    $@ = $disp;
    $disp->success;
}


sub trace(@)   {report TRACE   => @_}
sub assert(@)  {report ASSERT  => @_}
sub info(@)    {report INFO    => @_}
sub notice(@)  {report NOTICE  => @_}
sub warning(@) {report WARNING => @_}
sub mistake(@) {report MISTAKE => @_}
sub error(@)   {report ERROR   => @_}
sub fault(@)   {report FAULT   => @_}
sub alert(@)   {report ALERT   => @_}
sub failure(@) {report FAILURE => @_}
sub panic(@)   {report PANIC   => @_}


sub _default_domain(@)
{   my $f = $domain_start{$_[1]} or return undef;
    my $domain;
    do { $domain = $_->[1] if $_->[0] < $_[2] } for @$f;
    $domain;
}

sub __($)
{  Log::Report::Message->new
    ( _msgid  => shift
    , _domain => _default_domain(caller)
    );
} 


# label "msgid" added before first argument
sub __x($@)
{   Log::Report::Message->new
     ( _msgid  => @_
     , _expand => 1
     , _domain => _default_domain(caller)
     );
} 


sub __n($$$@)
{   my ($single, $plural, $count) = (shift, shift, shift);
    Log::Report::Message->new
     ( _msgid  => $single
     , _plural => $plural
     , _count  => $count
     , _domain => _default_domain(caller)
     , @_
     );
}


sub __nx($$$@)
{   my ($single, $plural, $count) = (shift, shift, shift);
    Log::Report::Message->new
     ( _msgid  => $single
     , _plural => $plural
     , _count  => $count
     , _expand => 1
     , _domain => _default_domain(caller)
     , @_
     );
}


sub __xn($$$@)   # repeated for prototype
{   my ($single, $plural, $count) = (shift, shift, shift);
    Log::Report::Message->new
     ( _msgid  => $single
     , _plural => $plural
     , _count  => $count
     , _expand => 1
     , _domain => _default_domain(caller)
     , @_
     );
}


sub N__($) {shift}


sub N__n($$) {@_}


sub N__w(@) {split " ", $_[0]}


sub import(@)
{   my $class = shift;

    my $textdomain = @_%2 ? shift : undef;
    my %opts   = @_;
    my $syntax = delete $opts{syntax} || 'REPORT';
    my ($pkg, $fn, $linenr) = caller;

    if(my $trans = delete $opts{translator})
    {   $class->translator($textdomain, $trans, $pkg, $fn, $linenr);
    }

    push @{$domain_start{$fn}}, [$linenr => $textdomain];

    my @export = (@functions, @make_msg);
    push @export, @reason_functions
        if $syntax eq 'SHORT';

    $class->export_to_level(1, undef, @export);
}


sub translator($;$$$$)
{   my ($class, $domain) = (shift, shift);

    @_ or return $translator{$domain || 'rescue'} || $translator{rescue};

    defined $domain
        or error __"textdomain for translator not defined";

    my ($translator, $pkg, $fn, $line) = @_;
    ($pkg, $fn, $line) = caller    # direct call, not via import
        unless defined $pkg;

    if(my $t = $translator{$domain})
    {   error __x"textdomain '{domain}' configured twice. First: {fn} line {nr}"
            , domain => $domain, fn => $t->{filename}, nr => $t->{linenr};
    }

    $translator->isa('Log::Report::Translator')
        or error __"translator must be a Log::Report::Translator object";

    $translator{$domain} =
      { translator => $translator
      , package => $pkg, filename => $fn, linenr => $line
      };

    $translator;
}


sub isValidReason($) { $is_reason{$_[1]} }
sub isFatal($)       { $is_fatal{$_[1]} }


1;
