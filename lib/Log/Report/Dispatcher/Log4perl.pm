# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
use warnings;
use strict;

package Log::Report::Dispatcher::Log4perl;
use vars '$VERSION';
$VERSION = '0.992';

use base 'Log::Report::Dispatcher';

use Log::Report 'log-report', syntax => 'SHORT';
use Log::Report::Util  qw/@reasons expand_reasons/;

use Log::Log4perl qw/:levels/;

my %default_reasonToLevel =
 ( TRACE   => $DEBUG
 , ASSERT  => $DEBUG
 , INFO    => $INFO
 , NOTICE  => $INFO
 , WARNING => $WARN
 , MISTAKE => $WARN
 , ERROR   => $ERROR
 , FAULT   => $ERROR
 , ALERT   => $FATAL
 , FAILURE => $FATAL
 , PANIC   => $FATAL
 );

@reasons != keys %default_reasonToLevel
    and panic __"Not all reasons have a default translation";


sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);

    my $name   = $self->name;
    my $config = delete $args->{config}
       or error __x"Log::Log4perl back-end {name} requires a 'config' parameter"
            , name => $name;

    $self->{level}  = { %default_reasonToLevel };
    if(my $to_level = delete $args->{to_level})
    {   my @to = @$to_level;
        while(@to)
        {   my ($reasons, $level) = splice @to, 0, 2;
            my @reasons = expand_reasons $reasons;

            $level =~ m/^[0-5]$/
                or error __x "Log::Log4perl level '{level}' must be in 0-5"
                     , level => $level;

            $self->{level}{$_} = $level for @reasons;
        }
    }

    Log::Log4perl->init($config);

    $self->{appender} = Log::Log4perl->get_logger($name, %$args)
        or error __x"cannot find logger '{name}' in configuration {config}"
             , name => $name, config => $config;

    $self;
}

sub close()
{   my $self = shift;
    $self->SUPER::close or return;
    delete $self->{backend};
    $self;
}


sub appender() {shift->{appender}}


sub log($$$$)
{   my $self  = shift;
    my $text  = $self->SUPER::translate(@_) or return;
    my $level = $self->reasonToLevel($_[1]);

    $self->appender->log($level, $text);
    $self;
}


sub reasonToLevel($) { $_[0]->{level}{$_[1]} }

1;
