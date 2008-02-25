# Copyrights 2007-2008 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.03.
use warnings;
use strict;

package Log::Report::Exception;
use vars '$VERSION';
$VERSION = '0.15';

use Log::Report 'log-report';
use POSIX  qw/locale_h/;


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
{   my $self   = shift;
    my $opts   = @_ ? { %{$self->{report_opts}}, @_ } : $self->{report_opts};
    my $reason = delete $opts->{reason} || $self->reason;
    report $opts, $reason, $self->message;
}

1;
