# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
use warnings;
use strict;

package Log::Report::Dispatcher::Callback;
use vars '$VERSION';
$VERSION = '0.96';

use base 'Log::Report::Dispatcher';

use Log::Report 'log-report';


sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);

    $self->{callback} = $args->{callback}
        or error __x"dispatcher {name} needs a 'callback'", name => $self->name;

    $self;
}


sub callback() {shift->{callback}}


sub log($$$)
{   my $self = shift;
    $self->{callback}->($self, @_);
}

1;
