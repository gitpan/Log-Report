# Copyrights 2007 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.00.
use warnings;
use strict;

package Log::Report::Dispatcher::Try;
use vars '$VERSION';
$VERSION = '0.02';
use base 'Log::Report::Dispatcher';

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Exception;


use overload
    bool => 'failed'
  , '""' => 'printError';


sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);
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

    push @{$self->{exceptions}},
       Log::Report::Exception->new
         ( reason      => $reason
         , report_opts => $opts
         , message     => $message
         );

    $self;
}


sub reportAll() { $_->throw for shift->exceptions }


sub reportFatal() { $_->throw for shift->wasFatal }


sub failed()  {   shift->{died}}
sub success() { ! shift->{died}}


sub wasFatal()
{   my $self = shift;
    $self->{died} ? $self->{exceptions}[-1] : ();
}


sub printError()
{   my $fatal = shift->wasFatal or return '';
    # don't use '.', because it is overloaded for message
    join('', $fatal->reason, ': ', $fatal->message, "\n");
}

1;
