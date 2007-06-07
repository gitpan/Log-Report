# Copyrights 2007 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.00.
use warnings;
use strict;

package Log::Report::Dispatcher::File;
use vars '$VERSION';
$VERSION = '0.05';
use base 'Log::Report::Dispatcher';

use Log::Report 'log-report', syntax => 'SHORT';
use IO::File;


sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);
    my $name = $self->name;
    my $to   = delete $args->{to}
        or error __x"dispatcher {name} needs parameter 'to'", name => $name;

    if(ref $to)
    {   $self->{output} = $to;
        trace "opened dispatcher $name to a ".ref($to);
    }
    else
    {   $self->{filename} = $to;
        my $mode    = $args->{replace} ? '>' : '>>';
        my $charset = delete $args->{charset} || 'utf-8';
        my $binmode = "$mode:encoding($charset)";

        $self->{output} = IO::File->new($to, $binmode)
            or fault __x"cannot write log into {file} with {binmode}"
                   , binmode => $binmode, file => $to;

        trace "opened dispatcher $name to $to with $binmode";
    }

    $self;
}


sub close()
{   my $self = shift;
    $self->SUPER::close or return;
    $self->{output}->close if $self->{filename};
    $self;
}


sub filename() {shift->{filename}}


sub log($$$)
{   my $self = shift;
    $self->{output}->print($self->SUPER::translate(@_));
}

1;
