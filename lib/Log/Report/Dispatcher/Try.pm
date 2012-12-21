# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
use warnings;
use strict;

package Log::Report::Dispatcher::Try;
use vars '$VERSION';
$VERSION = '0.992';

use base 'Log::Report::Dispatcher';

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Exception;


use overload
    bool => 'failed'
  , '""' => 'showStatus';


sub init($)
{   my ($self, $args) = @_;
    defined $self->SUPER::init($args) or return;
    $self->{exceptions} = delete $args->{exceptions} || [];
    $self->{died} = delete $args->{died};
    $self;
}


sub close()
{   my $self = shift;
    $self->SUPER::close or return;
    $self;
}


sub died(;$)
{   my $self = shift;
    @_ ? ($self->{died} = shift) : $self->{died};
}


sub exceptions() { @{shift->{exceptions}} }


sub log($$$)
{   my ($self, $opts, $reason, $message) = @_;

    # If "try" does not want a stack, because of its mode,
    # then don't produce one later!  (too late)
    $opts->{stack}    ||= [];
    $opts->{location} ||= '';

    push @{$self->{exceptions}}
      , Log::Report::Exception->new
          ( reason      => $reason
          , report_opts => $opts
          , message     => $message
          );

    # later changed into nice message
    $self->{died} ||= $opts->{is_fatal};
    $self;
}


sub reportAll(@) { $_->throw(@_) for shift->exceptions }


sub reportFatal(@) { $_->throw(@_) for shift->wasFatal }

#-----------------


sub failed()  {   shift->{died}}
sub success() { ! shift->{died}}


sub wasFatal(@)
{   my ($self, %args) = @_;
    $self->{died} or return ();
    my $ex = $self->{exceptions}[-1];
    (!$args{class} || $ex->inClass($args{class})) ? $ex : ();
}


sub showStatus()
{   my $self  = shift;
    my $fatal = $self->wasFatal or return '';
    __x"try-block stopped with {reason}: {text}"
      , reason => $fatal->reason
      , text   => $self->died;
}

1;
