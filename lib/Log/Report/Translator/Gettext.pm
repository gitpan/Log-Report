# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
use warnings;
use strict;

package Log::Report::Translator::Gettext;
use vars '$VERSION';
$VERSION = '0.992';

use base 'Log::Report::Translator';

use Locale::gettext;

use Log::Report 'log-report';


sub translate($;$)
{   my ($msg, $lang) = @_;

#XXX MO: how to use $lang when specified?
    my $domain = $msg->{_textdomain};
    load_domain $domain;

    my $count  = $msg->{_count};

    defined $count
    ? ( defined $msg->{_category}
      ? dcngettext($domain, $msg->{_msgid}, $msg->{_plural}, $count
                  , $msg->{_category})
      : dngettext($domain, $msg->{_msgid}, $msg->{_plural}, $count)
      )
    : ( defined $msg->{_category}
      ? dcgettext($domain, $msg->{_msgid}, $msg->{_category})
      : dgettext($domain, $msg->{_msgid})
      );
}

1;
