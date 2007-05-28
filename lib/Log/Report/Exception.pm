# Copyrights 2007 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.00.
use warnings;
use strict;

package Log::Report::Exception;
use vars '$VERSION';
$VERSION = '0.03';

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


# if we would used "report" here, we get a naming conflict with
# function Log::Report::report.
sub throw(@)
{   my $self = shift;
    my $opts = @_ ? { %{$self->{report_opts}}, @_ } : $self->{report_opts};
    report $opts, $self->reason, $self->message;
}

1;
