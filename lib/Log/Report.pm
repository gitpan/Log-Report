# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.

use warnings;
use strict;

package Log::Report;
use vars '$VERSION';
$VERSION = '0.992';

use base 'Exporter';

use List::Util qw/first/;

# domain 'log-report' via work-arounds:
#     Log::Report cannot do "use Log::Report"

my @make_msg         = qw/__ __x __n __nx __xn N__ N__n N__w/;
my @functions        = qw/report dispatcher try/;
my @reason_functions = qw/trace assert info notice warning
   mistake error fault alert failure panic/;

our @EXPORT_OK = (@make_msg, @functions, @reason_functions);

require Log::Report::Util;
require Log::Report::Message;
require Log::Report::Dispatcher;
require Log::Report::Dispatcher::Try;

# See section Run modes
my %is_reason = map {($_=>1)} @Log::Report::Util::reasons;
my %is_fatal  = map {($_=>1)} qw/ERROR FAULT FAILURE PANIC/;
my %use_errno = map {($_=>1)} qw/FAULT ALERT FAILURE/;

sub _whats_needed(); sub dispatcher($@);
sub trace(@); sub assert(@); sub info(@); sub notice(@); sub warning(@);
sub mistake(@); sub error(@); sub fault(@); sub alert(@); sub failure(@);
sub panic(@);
sub __($); sub __x($@); sub __n($$$@); sub __nx($$$@); sub __xn($$$@);
sub N__($); sub N__n($$); sub N__w(@);

require Log::Report::Translator::POT;

my $reporter;
my %domain_start;
my %settings;
my $default_mode = 0;

#
# Some initiations
#

__PACKAGE__->_setting('log-report', translator =>
    Log::Report::Translator::POT->new(charset => 'utf-8'));

__PACKAGE__->_setting('rescue', translator => Log::Report::Translator->new);

dispatcher PERL => 'default', accept => 'NOTICE-';


# $^S = $EXCEPTIONS_BEING_CAUGHT; parse: undef, eval: 1, else 0

sub report($@)
{   my $opts   = ref $_[0] eq 'HASH' ? +{ %{ (shift) } } : {};
    my $reason = shift;
    my $stop = exists $opts->{is_fatal} ? $opts->{is_fatal} :$is_fatal{$reason};

    # return when no-one needs it: skip unused trace() fast!
    my $disp = $reporter->{needs}{$reason};
    $disp || $stop or return;

    $is_reason{$reason}
        or error __x"token '{token}' not recognized as reason", token=>$reason;

    $opts->{errno} ||= $!+0 || $? || 1
        if $use_errno{$reason} && !defined $opts->{errno};

    if(my $to = delete $opts->{to})
    {   # explicit destination, still disp may not need it.
        if(ref $to eq 'ARRAY')
        {   my %disp = map {$_->name => $_} @$disp;
            $disp    = [ grep defined, @disp{@$to} ];
        }
        else
        {   $disp    = [ grep $_->name eq $to, @$disp ];
        }
        @$disp || $stop
            or return;
    }

    $opts->{location} ||= Log::Report::Dispatcher->collectLocation;

    my $message = shift;
    my $exception;
    if(UNIVERSAL::isa($message, 'Log::Report::Message'))
    {   @_==0 or error __x"a message object is reported with more parameters";
    }
    elsif(UNIVERSAL::isa($message, 'Log::Report::Exception'))
    {   $exception = $message;
        $message   = $exception->message;
    }
    else
    {   # untranslated message into object
        @_%2 and error __x"odd length parameter list with '{msg}'", msg => $message;
        $message = Log::Report::Message->new(_prepend => $message, @_);
    }

    if(my $to = $message->to)
    {   $disp    = [ grep $_->name eq $to, @$disp ];
        @$disp or return;
    }

    my @last_call;     # call Perl dispatcher always last
    if($reporter->{filters})
    {
      DISPATCHER:
        foreach my $d (@$disp)
        {   my ($r, $m) = ($reason, $message);
            foreach my $filter ( @{$reporter->{filters}} )
            {   next if keys %{$filter->[1]} && !$filter->[1]{$d->name};
                ($r, $m) = $filter->[0]->($d, $opts, $r, $m);
                $r or next DISPATCHER;
            }

            if($d->isa('Log::Report::Dispatcher::Perl'))
                 { @last_call = ($d, { %$opts }, $r, $m) }
            else { $d->log($opts, $r, $m) }
        }
    }
    else
    {   foreach my $d (@$disp)
        {   if($d->isa('Log::Report::Dispatcher::Perl'))
                 { @last_call = ($d, { %$opts }, $reason, $message) }
            else { $d->log($opts, $reason, $message) }
        }
    }

    if(@last_call)
    {   # the PERL dispatcher may terminate the program
        shift(@last_call)->log(@last_call);
    }

    if($stop)
    {   # ^S = EXCEPTIONS_BEING_CAUGHT, within eval or try
        $^S or exit($opts->{errno} || 0);

        $! = $opts->{errno} || 0;
        $@ = $exception || Log::Report::Exception->new(report_opts => $opts
          , reason => $reason, message => $message);
        die;   # $@->PROPAGATE() will be called, some eval will catch this
    }

    @$disp;
}


sub dispatcher($@)
{   if($_[0] !~ m/^(?:close|find|list|disable|enable|mode|needs|filter)$/)
    {   my ($type, $name) = (shift, shift);
        my $disp = Log::Report::Dispatcher->new($type, $name
          , mode => $default_mode, @_);
        defined $disp or return;  # use defined, because $disp is overloaded

        # old dispatcher with same name will be closed in DESTROY
        $reporter->{dispatchers}{$name} = $disp;
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

    my $mode     = $command eq 'mode' ? shift : undef;

    my $all_disp = @_==1 && $_[0] eq 'ALL';
    my @disps    = $all_disp ? keys %{$reporter->{dispatchers}} : @_;

    my @dispatchers = grep defined, @{$reporter->{dispatchers}}{@disps};
    @dispatchers or return;

    error __"only one dispatcher name accepted in SCALAR context"
        if @dispatchers > 1 && !wantarray && defined wantarray;

    if($command eq 'close')
    {   delete @{$reporter->{dispatchers}}{@disps};
        $_->close for @dispatchers;
    }
    elsif($command eq 'enable')  { $_->_disabled(0) for @dispatchers }
    elsif($command eq 'disable') { $_->_disabled(1) for @dispatchers }
    elsif($command eq 'mode')
    {    Log::Report::Dispatcher->defaultMode($mode) if $all_disp;
         $_->_set_mode($mode) for @dispatchers;
    }

    # find does require reinventarization
    _whats_needed unless $command eq 'find';

    wantarray ? @dispatchers : $dispatchers[0];
}

END { $_->close for grep defined, values %{$reporter->{dispatchers}} }

# _whats_needed
# Investigate from all dispatchers which reasons will need to be
# passed on. After dispatchers are added, enabled, or disabled,
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

    @_ % 2
      and report {location => [caller 0]}, PANIC =>
          __x"odd length parameter list for try(): forgot the terminating ';'?";

    local $reporter->{dispatchers} = undef;
    local $reporter->{needs};

    my $disp = dispatcher TRY => 'try', @_;

    my ($ret, @ret);
    if(!defined wantarray)  { eval { $code->() } } # VOID   context
    elsif(wantarray) { @ret = eval { $code->() } } # LIST   context
    else             { $ret = eval { $code->() } } # SCALAR context

    my $err = $@;
    if(   $err
       && !$disp->wasFatal
       && !UNIVERSAL::isa($err, 'Log::Report::Exception'))
    {   eval "require Log::Report::Die"; panic $@ if $@;
        ($err, my($opts, $reason, $text)) = Log::Report::Die::die_decode($err);
        $disp->log($opts, $reason, __$text);
    }

    $disp->died($err);
    $@ = $disp;

    wantarray ? @ret : $ret;
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
{   Log::Report::Message->new
      ( _msgid  => shift
      , _domain => _default_domain(caller)
      );
} 


# label "msgid" added before first argument
sub __x($@)
{   @_%2 or error __x"even length parameter list for __x at {where}",
        where => join(' line ', (caller)[1,2]);

    Log::Report::Message->new
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
    my $syntax = delete $opts{syntax} || 'SHORT';
    my ($pkg, $fn, $linenr) = caller;

    if(my $trans = delete $opts{translator})
    {   $class->translator($textdomain, $trans, $pkg, $fn, $linenr);
    }

    if(my $native = delete $opts{native_language})
    {   my ($lang) = parse_locale $native;

        error "the specified native_language '{locale}' is not a valid locale"
          , locale => $native unless defined $lang;

        $class->_setting($textdomain, native_language => $native
          , $pkg, $fn, $linenr);
    }

    if(exists $opts{mode})
    {   $default_mode = delete $opts{mode} || 0;
        Log::Report::Dispatcher->defaultMode($default_mode);
        dispatcher mode => $default_mode, 'ALL';
    }

    push @{$domain_start{$fn}}, [$linenr => $textdomain];

    my @export = (@functions, @make_msg);

    if($syntax eq 'SHORT')
    {   push @export, @reason_functions
    }
    elsif($syntax ne 'REPORT' && $syntax ne 'LONG')
    {   error __x"syntax flag must be either SHORT or REPORT, not `{syntax}'"
          , syntax => $syntax;
    }

    $class->export_to_level(1, undef, @export);
}


sub translator($;$$$$)
{   my ($class, $domain) = (shift, shift);

    @_ or return $class->_setting($domain => 'translator')
              || $class->_setting(rescue  => 'translator');

    defined $domain
        or error __"textdomain for translator not defined";

    my ($translator, $pkg, $fn, $line) = @_;
    ($pkg, $fn, $line) = caller    # direct call, not via import
        unless defined $pkg;

    $translator->isa('Log::Report::Translator')
        or error __"translator must be a Log::Report::Translator object";

    $class->_setting($domain, translator => $translator, $pkg, $fn, $line);
}

# c_method setting TEXTDOMAIN, NAME, [VALUE]
# When a VALUE is provided (of unknown structure) then it is stored for the
# NAME related to TEXTDOMAIN.  Otherwise, the value related to the NAME is
# returned.  The VALUEs may only be set once in your program, and count for
# all packages in the same TEXTDOMAIN.

sub _setting($$;$)
{   my ($class, $domain, $name, $value) = splice @_, 0, 4;
    $domain ||= 'rescue';

    defined $value
        or return $settings{$domain}{$name};

    # Where is the setting done?
    my ($pkg, $fn, $line) = @_;
    ($pkg, $fn, $line) = caller    # direct call, not via import
         unless defined $pkg;

    my $s = $settings{$domain} ||= {_pkg => $pkg, _fn => $fn, _line => $line};

    error __x"only one package can contain configuration; for {domain} already in {pkg} in file {fn} line {line}"
        , domain => $domain, pkg => $s->{_pkg}
        , fn => $s->{_fn}, line => $s->{_line}
           if $s->{_pkg} ne $pkg || $s->{_fn} ne $fn;

    error __x"value for {name} specified twice", name => $name
        if exists $s->{$name};

    $s->{$name} = $value;
}


sub isValidReason($) { $is_reason{$_[1]} }
sub isFatal($)       { $is_fatal{$_[1]} }


sub needs(@)
{   my $thing = shift;
    my $self  = ref $thing ? $thing : $reporter;
    first {$self->{needs}{$_}} @_;
}


1;
