# Copyrights 2007-2011 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
use warnings;
use strict;

package Log::Report::Message;
use vars '$VERSION';
$VERSION = '0.92';


use Log::Report 'log-report';
use POSIX      qw/locale_h/;
use List::Util qw/first/;


use overload
    '""'  => 'toString'
  , '&{}' => sub { my $obj = shift; sub{$obj->clone(@_)} }
  , '.'   => 'concat';


sub new($@) { my $class = shift; bless {@_}, $class }


sub clone(@)
{   my $self = shift;
    (ref $self)->new(%$self, @_);
}


sub prepend() {shift->{_prepend}}
sub msgid()   {shift->{_msgid}}
sub append()  {shift->{_append}}
sub domain()  {shift->{_domain}}
sub count()   {shift->{_count}}


sub classes()
{   my $class = $_[0]->{_class} || $_[0]->{_classes} || [];
    ref $class ? @$class : split(/[\s,]+/, $class);
}


sub to(;$)
{   my $self = shift;
    @_ ? $self->{_to} = shift : $self->{_to};
}


sub valueOf($) { $_[0]->{$_[1]} }


sub inClass($)
{   my @classes = shift->classes;
       ref $_[0] eq 'Regexp'
    ? (first { $_ =~ $_[0] } @classes)
    : (first { $_ eq $_[0] } @classes);
}
    

sub toString(;$)
{   my ($self, $locale) = @_;
    my $count  = $self->{_count} || 0;

    $self->{_msgid}   # no translation, constant string
        or return (defined $self->{_prepend} ? $self->{_prepend} : '')
                . (defined $self->{_append}  ? $self->{_append}  : '');

    # create a translation
    my $text = Log::Report->translator($self->{_domain})->translate($self);
    defined $text or return ();

    my $loc  = defined $locale ? setlocale(LC_ALL, $locale) : undef;

    if($self->{_expand})
    {    my $re   = join '|', map { quotemeta $_ } keys %$self;
         $text    =~ s/\{($re)(\%[^}]*)?\}/$self->_expand($1,$2)/ge;
    }

    $text  = "$self->{_prepend}$text"
        if defined $self->{_prepend};

    $text .= "$self->{_append}"
        if defined $self->{_append};

    setlocale(LC_ALL, $loc) if $loc;

    $text;
}

sub _expand($$)
{   my ($self, $key, $format) = @_;
    my $value = $self->{$key};

    $value = $value->($self)
        while ref $value eq 'CODE';

    defined $value
        or return "undef";

    use locale;
    if(ref $value eq 'ARRAY')
    {   my @values = map {defined $_ ? $_ : 'undef'} @$value;
        @values or return '(none)';
        return $format
             ? join($", map {sprintf $format, $_} @values)
             : join($", @values);
    }

      $format
    ? sprintf($format, $value)
    : "$value";   # enforce stringification on objects
}


sub untranslated()
{  my $self = shift;
     (defined $self->{_prepend} ? $self->{_prepend} : '')
   . (defined $self->{_msgid}   ? $self->{_msgid}   : '')
   . (defined $self->{_append}  ? $self->{_append}  : '');
}


sub concat($;$)
{   my ($self, $what, $reversed) = @_;
    if($reversed)
    {   $what .= $self->{_prepend} if defined $self->{_prepend};
        return ref($self)->new(%$self, _prepend => $what);
    }

    $what = $self->{_append} . $what if defined $self->{_append};
    ref($self)->new(%$self, _append => $what);
}


1;
