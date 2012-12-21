# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
use warnings;
use strict;

package Log::Report::Dispatcher::Syslog;
use vars '$VERSION';
$VERSION = '0.992';

use base 'Log::Report::Dispatcher';

use Sys::Syslog qw/:standard :extended :macros/;
use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Util  qw/@reasons expand_reasons/;

use File::Basename qw/basename/;

my %default_reasonToPrio =
 ( TRACE   => LOG_DEBUG
 , ASSERT  => LOG_DEBUG
 , INFO    => LOG_INFO
 , NOTICE  => LOG_NOTICE
 , WARNING => LOG_WARNING
 , MISTAKE => LOG_WARNING
 , ERROR   => LOG_ERR
 , FAULT   => LOG_ERR
 , ALERT   => LOG_ALERT
 , FAILURE => LOG_EMERG
 , PANIC   => LOG_CRIT
 );

@reasons != keys %default_reasonToPrio
    and panic __"Not all reasons have a default translation";


sub init($)
{   my ($self, $args) = @_;
    $args->{format_reason} ||= 'IGNORE';

    $self->SUPER::init($args);

    setlogsock(delete $args->{logsocket})
        if $args->{logsocket};

    my $ident = delete $args->{identity} || basename $0;
    my $flags = delete $args->{flags}    || 'pid,nowait';
    my $fac   = delete $args->{facility} || 'user';
    openlog $ident, $flags, $fac;   # doesn't produce error.

    $self->{prio} = { %default_reasonToPrio };
    if(my $to_prio = delete $args->{to_prio})
    {   my @to = @$to_prio;
        while(@to)
        {   my ($reasons, $level) = splice @to, 0, 2;
            my @reasons = expand_reasons $reasons;

            my $prio    = Sys::Syslog::xlate($level);
            error __x"syslog level '{level}' not understood", level => $level
                if $prio eq -1;

            $self->{prio}{$_} = $prio for @reasons;
        }
    }

    $self;
}

sub close()
{   my $self = shift;
    closelog;
    $self->SUPER::close;
}


sub log($$$$)
{   my $self = shift;
    my $text = $self->SUPER::translate(@_) or return;

    my $prio = $self->reasonToPrio($_[1]);

    # handle each line in message separately
    syslog $prio, "%s", $_
        for split /\n/, $text;
}


sub reasonToPrio($) { $_[0]->{prio}{$_[1]} }

1;
