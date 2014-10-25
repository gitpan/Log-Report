# Copyrights 2007-2012 by [Mark Overmeer].
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.00.
package DieTests;
use vars '$VERSION';
$VERSION = '0.992';

use warnings;
use strict;

use Log::Report::Die qw/die_decode/;
use Log::Report      qw/log-report/;
use Carp;

use Test::More tests => 27;
use DieTests;

$! = 3;
my $errno  = $!+0;
my $errstr = "$!";

sub process($)
{
    my ($err, $opt, $reason, $message) = die_decode shift;
    $err =~ s/\d+\.?$/XX/;
    my $errno = $opt->{errno}    || 'no errno';
    my $loc   = $opt->{location};
    my $loca  = $loc ? "$loc->[1]#XX" : 'no location';
    my $stack = join "\n",
                    map { join '#', $_->[0], $_->[1], 'XX' }
                        @{$opt->{stack}};
    <<__RESULT
$reason: $message ($errno)
$err
$loca
$stack
__RESULT
}

sub run_tests()
{

###
#### Testing die_decode itself
###

ok(1, "err $errno is '$errstr'");

# die

eval { die "ouch" };
my $die_text1 = $@;
is(process($die_text1),  <<__OUT, "die");
ERROR: ouch (no errno)
ouch at t/DieTests.pm line XX
t/DieTests.pm#XX

__OUT

eval { die "ouch\n" };
my $die_text2 = $@;
is(process($die_text2),  <<__OUT, "die");
ERROR: ouch (no errno)
ouch
no location

__OUT

eval { $! = $errno; die "ouch $!" };
my $die_text3 = $@;
is(process($die_text3),  <<__OUT, "die");
FAULT: ouch (3)
ouch No such process at t/DieTests.pm line XX
t/DieTests.pm#XX

__OUT

eval { $! = $errno; die "ouch $!\n" };
my $die_text4 = $@;
is(process($die_text4),  <<__OUT, "die");
FAULT: ouch (3)
ouch No such process
no location

__OUT

# croak

eval { croak "ouch" };
my $croak_text1 = $@;
is(process($croak_text1),  <<__OUT, "croak");
ERROR: ouch (no errno)
ouch at t/41die.t line XX
t/41die.t#XX

__OUT

eval { croak "ouch\n" };
my $croak_text2 = $@;
is(process($croak_text2),  <<__OUT, "croak");
ERROR: ouch (no errno)
ouch
t/41die.t#XX

__OUT

eval { $! = $errno; croak "ouch $!" };
my $croak_text3 = $@;
is(process($croak_text3),  <<__OUT, "croak");
FAULT: ouch (3)
ouch No such process at t/41die.t line XX
t/41die.t#XX

__OUT

eval { $! = $errno; croak "ouch $!\n" };
my $croak_text4 = $@;
is(process($croak_text4),  <<__OUT, "croak");
FAULT: ouch (3)
ouch No such process
t/41die.t#XX

__OUT

# confess

eval { confess "ouch" };
my $confess_text1 = $@;
is(process($confess_text1),  <<__OUT, "confess");
PANIC: ouch (no errno)
ouch at t/DieTests.pm line XX
t/DieTests.pm#XX
eval {...}#t/DieTests.pm#XX
DieTests::run_tests()#t/41die.t#XX
main::simple_wrapper()#t/41die.t#XX
__OUT

eval { confess "ouch\n" };
my $confess_text2 = $@;
is(process($confess_text2),  <<__OUT, "confess");
PANIC: ouch (no errno)
ouch
t/DieTests.pm#XX
eval {...}#t/DieTests.pm#XX
DieTests::run_tests()#t/41die.t#XX
main::simple_wrapper()#t/41die.t#XX
__OUT

eval { $! = $errno; confess "ouch $!" };
my $confess_text3 = $@;
is(process($confess_text3),  <<__OUT, "confess");
ALERT: ouch (3)
ouch No such process at t/DieTests.pm line XX
t/DieTests.pm#XX
eval {...}#t/DieTests.pm#XX
DieTests::run_tests()#t/41die.t#XX
main::simple_wrapper()#t/41die.t#XX
__OUT


if($^O eq 'MSWin32')
{   # perl bug http://rt.perl.org/rt3/Ticket/Display.html?id=81586
    pass 'Win32/confess bug #81586';
}
else
{

eval { $! = $errno; confess "ouch $!\n" };
my $confess_text4 = $@;
is(process($confess_text4),  <<__OUT, "confess");
ALERT: ouch (3)
ouch No such process
t/DieTests.pm#XX
eval {...}#t/DieTests.pm#XX
DieTests::run_tests()#t/41die.t#XX
main::simple_wrapper()#t/41die.t#XX
__OUT

}

###
#### Testing try{} with various die's
##

my $r = try { die "Arggghh!"; 1 };
ok(defined $@, "try before you die");
ok(!$r, "no value returned");
isa_ok($@, 'Log::Report::Dispatcher::Try');
my $fatal1 = $@->wasFatal;
isa_ok($fatal1, 'Log::Report::Exception');
my $msg1   = $fatal1->message;
isa_ok($msg1, 'Log::Report::Message');
is("$msg1", 'Arggghh!');

try { eval "program not perl"; die $@ if $@ };
ok(defined $@, "parse not perl");
my $fatal2 = $@->wasFatal;
isa_ok($fatal2, 'Log::Report::Exception');
my $msg2   = $fatal2->message;
isa_ok($msg2, 'Log::Report::Message');
like("$msg2", qr/^syntax error at \(eval \d+\) line 1, near \"program not \"/);

eval <<'__TEST'
   try { require "Does::Not::Exist";
       };
   ok(defined $@, "perl error");
   my $fatal3 = $@->wasFatal;
   isa_ok($fatal3, 'Log::Report::Exception');
   my $msg3   = $fatal3->message;
   isa_ok($msg3, 'Log::Report::Message');
   like("$msg3", qr/^Can\'t locate Does\:\:Not\:\:Exist in \@INC /);
__TEST


}  # run_tests()

1;
