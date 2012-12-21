# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
package Log::Report::Lexicon::POT;
use vars '$VERSION';
$VERSION = '0.992';

use base 'Log::Report::Lexicon::Table';

use warnings;
use strict;

use Log::Report 'log-report';
use Log::Report::Lexicon::PO  ();

use POSIX       qw/strftime/;
use List::Util  qw/sum/;

use constant    MSGID_HEADER => '';


sub init($)
{   my ($self, $args) = @_;

    $self->{filename} = $args->{filename};
    $self->{charset}  = $args->{charset}
       or error __x"charset parameter is required for {fn}"
            , fn => ($args->{filename} || __"unnamed file");

    my $version    = $args->{version};
    my $domain     = $args->{textdomain}
       or error __"textdomain parameter is required";

    my $forms      = $args->{plural_forms};
    unless($forms)
    {   my $nrplurals = $args->{nr_plurals} || 2;
        my $algo      = $args->{plural_alg} || 'n!=1';
        $forms        = "nplurals=$nrplurals; plural=($algo);";
    }

    $self->{index} = $args->{index} || {};
    $self->_createHeader
     ( project => $domain . (defined $version ? " $version" : '')
     , forms   => $forms
     , charset => $args->{charset}
     , date    => $args->{date}
     );

    $self->setupPluralAlgorithm;
    $self;
}


sub read($@)
{   my ($class, $fn, %args) = @_;

    my $self    = bless {}, $class;

    my $charset = $self->{charset} = $args{charset}
        or error __x"charset parameter is required for {fn}", fn => $fn;

    open my $fh, "<:encoding($charset)", $fn
        or fault __x"cannot read in {cs} from file {fn}"
             , cs => $charset, fn => $fn;

    local $/   = "\n\n";
    my $linenr = 1;  # $/ frustrates $fh->input_line_number
    while(1)
    {   my $location = "$fn line $linenr";
        my $block    = <$fh>;
        defined $block or last;

        $linenr += $block =~ tr/\n//;

        $block   =~ s/\s+\z//s;
        length $block or last;

        my $po = Log::Report::Lexicon::PO->fromText($block, $location);
        $self->add($po) if $po;
    }

    close $fh
        or failure __x"failed reading from file {fn}", fn => $fn;

    $self->{filename} = $fn;
    $self->setupPluralAlgorithm;
    $self;
}


sub write($@)
{   my $self = shift;
    my $file = @_%2 ? shift : $self->filename;
    my %args = @_;

    defined $file
        or error __"no filename or file-handle specified for PO";

    my @opt  = (nplurals => $self->nrPlurals);

    my $fh;
    if(ref $file) { $fh = $file }
    else
    {    my $layers = '>:encoding('.$self->charset.')';
         open $fh, $layers, $file
             or fault __x"cannot write to file {fn} in {layers}"
                    , fn => $file, layers => $layers;
    }

    $fh->print($self->msgid(MSGID_HEADER)->toString(@opt));
    my $index = $self->index;
    foreach my $msgid (sort keys %$index)
    {   next if $msgid eq MSGID_HEADER;

        my $po = $index->{$msgid};
        next if $po->unused;

        $fh->print("\n", $po->toString(@opt));
    }

    $fh->close
        or failure __x"write errors for file {fn}", fn => $file;

    $self;
}

#-----------------------

sub charset()  {shift->{charset}}
sub index()    {shift->{index}}
sub filename() {shift->{filename}}

#-----------------------

sub msgid($) { $_[0]->{index}{$_[1]} }


sub msgstr($;$)
{   my $self = shift;
    my $po   = $self->msgid(shift)
        or return undef;

    $po->msgstr($self->pluralIndex(defined $_[0] ? $_[0] : 1));
}


sub add($)
{   my ($self, $po) = @_;
    my $msgid = $po->msgid;

    $self->{index}{$msgid}
       and error __x"translation already exists for '{msgid}'", msgid => $msgid;

    $self->{index}{$msgid} = $po;
}


sub translations(;$)
{   my $self = shift;
    @_ or return values %{$self->{index}};

    error __x"the only acceptable parameter is 'ACTIVE', not '{p}'", p => $_[0]
        if $_[0] ne 'ACTIVE';

    grep { $_->isActive } $self->translations;
}


sub _now() { strftime "%Y-%m-%d %H:%M%z", localtime }

sub header($;$)
{   my ($self, $field) = (shift, shift);
    my $header = $self->msgid(MSGID_HEADER)
        or error __x"no header defined in POT for file {fn}"
                   , fn => $self->filename;

    if(!@_)
    {   my $text = $header->msgstr(0) || '';
        return $text =~ m/^\Q$field\E\:\s*([^\n]*?)\;?\s*$/im ? $1 : undef;
    }

    my $content = shift;
    my $text    = $header->msgstr(0);

    for($text)
    {   if(defined $content)
        {   s/^\Q$field\E\:([^\n]*)/$field: $content/im  # change
         || s/\z/$field: $content\n/;      # new
        }
        else
        {   s/^\Q$field\E\:[^\n]*\n?//im;  # remove
        }
    }

    $header->msgstr(0, $text);
    $content;
}


sub updated(;$)
{   my $self = shift;
    my $date = shift || _now;
    $self->header('PO-Revision-Date', $date);
    $date;
}

### internal
sub _createHeader(%)
{   my ($self, %args) = @_;
    my $date   = $args{date} || _now;

    my $header = Log::Report::Lexicon::PO->new
     (  msgid  => MSGID_HEADER, msgstr => <<__CONFIG);
Project-Id-Version: $args{project}
Report-Msgid-Bugs-To:
POT-Creation-Date: $date
PO-Revision-Date: $date
Last-Translator:
Language-Team:
MIME-Version: 1.0
Content-Type: text/plain; charset=$args{charset}
Content-Transfer-Encoding: 8bit
Plural-Forms: $args{forms}
__CONFIG

    my $version = $Log::Report::VERSION || '0.0';
    $header->addAutomatic("Header generated with ".__PACKAGE__." $version\n");

    $self->index->{&MSGID_HEADER} = $header
        if $header;

    $header;
}


sub removeReferencesTo($)
{   my ($self, $filename) = @_;
    sum map { $_->removeReferencesTo($filename) } $self->translations;
}


sub stats()
{   my $self  = shift;
    my %stats = (msgids => 0, fuzzy => 0, inactive => 0);
    foreach my $po ($self->translations)
    {   next if $po->msgid eq MSGID_HEADER;
        $stats{msgids}++;
        $stats{fuzzy}++    if $po->fuzzy;
        $stats{inactive}++ if !$po->isActive && !$po->unused;
    }
    \%stats;
}

1;
