# Copyrights 2007-2011 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.07.
use warnings;
use strict;

package Log::Report::Exception;
use vars '$VERSION';
$VERSION = '0.91';


use Log::Report 'log-report';
use POSIX  qw/locale_h/;


use overload '""' => 'toString';


sub new($@)
{   my ($class, %args) = @_;
    $args{report_opts} ||= {};
    bless \%args, $class;
}


sub report_opts() {shift->{report_opts}}
sub reason()      {shift->{reason}}
sub message()     {shift->{message}}


sub inClass($) { $_[0]->message->inClass($_[1]) }


# if we would used "report" here, we get a naming conflict with
# function Log::Report::report.
sub throw(@)
{   my $self    = shift;
    my $opts    = @_ ? { %{$self->{report_opts}}, @_ } : $self->{report_opts};
    my $reason  = delete $opts->{reason} || $self->reason;

    $opts->{stack} = Log::Report::Dispatcher->collectStack
        if $opts->{stack} && @{$opts->{stack}};

    report $opts, $reason, $self;
}

# where the throw is handled is not interesting
sub PROPAGATE($$) {shift}


sub toString()
{   my $self = shift;
    my $msg  = $self->message;
    lc($self->reason) . ': ' . (ref $msg ? $msg->toString : $msg) . "\n";
}

1;
