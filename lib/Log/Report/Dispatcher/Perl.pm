# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
use warnings;
use strict;

package Log::Report::Dispatcher::Perl;
use vars '$VERSION';
$VERSION = '0.992';

use base 'Log::Report::Dispatcher';

use Log::Report 'log-report', syntax => 'SHORT';
use IO::File;

my $singleton = 0;   # can be only one (per thread)


sub log($$$)
{   my ($self, $opts, $reason, $message) = @_;
    my $text = $self->SUPER::translate($opts, $reason, $message);

    if($opts->{is_fatal})
    {   $! = $opts->{errno};
        die $text;
    }
    else
    {   warn $text;
    }
}

1;
