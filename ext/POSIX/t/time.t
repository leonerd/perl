#!perl -w

use strict;

use Config;
use POSIX;
use Test::More tests => 41;

# go to UTC to avoid DST issues around the world when testing.  SUS3 says that
# null should get you UTC, but some environments want the explicit names.
# Those with a working tzset() should be able to use the TZ below.
$ENV{TZ} = "UTC0UTC";

SKIP: {
    # It looks like POSIX.xs claims that only VMS and Mac OS traditional
    # don't have tzset().  Win32 works to call the function, but it doesn't
    # actually do anything.  Cygwin works in some places, but not others.  The
    # other Win32's below are guesses.
    skip "No tzset()", 2
       if $^O eq "MacOS" || $^O eq "VMS" || $^O eq "cygwin" || $^O eq "djgpp" ||
          $^O eq "MSWin32" || $^O eq "dos" || $^O eq "interix";
    tzset();
    my @tzname = tzname();
    like($tzname[0], qr/(GMT|UTC)/i, "tzset() to GMT/UTC");
    SKIP: {
        skip "Mac OS X/Darwin doesn't handle this", 1 if $^O =~ /darwin/i;
        like($tzname[1], qr/(GMT|UTC)/i, "The whole year?");
    }
}

if ($^O eq "hpux" && $Config{osvers} >= 11.3) {
    # HP does not support UTC0UTC and/or GMT0GMT, as they state that this is
    # legal syntax but as it has no DST rule, it cannot be used. That is the
    # conclusion of bug
    # QXCR1000896916: Some timezone valuesfailing on 11.31 that work on 11.23
    $ENV{TZ} = "UTC";
}

# asctime and ctime...Let's stay below INT_MAX for 32-bits and
# positive for some picky systems.

is(asctime(CORE::localtime(0)), ctime(0), "asctime() and ctime() at zero");
is(asctime(POSIX::localtime(0)), ctime(0), "asctime() and ctime() at zero");
is(asctime(CORE::localtime(12345678)), ctime(12345678),
   "asctime() and ctime() at 12345678");
is(asctime(POSIX::localtime(12345678)), ctime(12345678),
   "asctime() and ctime() at 12345678");

# Careful!  strftime() is locale sensitive.  Let's take care of that
my $orig_loc = setlocale(LC_TIME, "C") || die "Cannot setlocale() to C:  $!";
my $jan_16 = 15 * 86400;
is(ctime($jan_16), strftime("%a %b %d %H:%M:%S %Y\n", CORE::localtime($jan_16)),
        "get ctime() equal to strftime()");
is(ctime($jan_16), strftime("%a %b %d %H:%M:%S %Y\n", POSIX::localtime($jan_16)),
        "get ctime() equal to strftime()");
is(strftime("%Y\x{5e74}%m\x{6708}%d\x{65e5}", CORE::gmtime($jan_16)),
   "1970\x{5e74}01\x{6708}16\x{65e5}",
   "strftime() can handle unicode chars in the format string");
is(strftime("%Y\x{5e74}%m\x{6708}%d\x{65e5}", POSIX::gmtime($jan_16)),
   "1970\x{5e74}01\x{6708}16\x{65e5}",
   "strftime() can handle unicode chars in the format string");

my $ss = chr 223;
unlike($ss, qr/\w/, 'Not internally UTF-8 encoded');
is(ord strftime($ss, CORE::localtime), 223,
   'Format string has correct character');
is(ord strftime($ss, POSIX::localtime(time)),
   223, 'Format string has correct character');
unlike($ss, qr/\w/, 'Still not internally UTF-8 encoded');

my @time = POSIX::strptime("2011-12-18 12:34:56", "%Y-%m-%d %H:%M:%S");
is_deeply(\@time, [56, 34, 12, 18, 12-1, 2011-1900, 0, 351, 0], 'strptime() all 6 fields');

@time = POSIX::strptime("2011-12-18", "%Y-%m-%d", 1, 23, 4);
is_deeply(\@time, [1, 23, 4, 18, 12-1, 2011-1900, 0, 351, 0], 'strptime() all date fields with passed time');

@time = POSIX::strptime("2011-12-18", "%Y-%m-%d");
is_deeply(\@time, [undef, undef, undef, 18, 12-1, 2011-1900, 0, 351, 0], 'strptime() all date fields with no time');

# tm_year == 6 => 1906, which is a negative time_t. Lets use 106 as 2006 instead
@time = POSIX::strptime("12:34:56", "%H:%M:%S", 1, 2, 3, 4, 5, 106);
is_deeply(\@time, [56, 34, 12, 4, 5, 106, 0, 154, 1], 'strptime() all time fields with passed date');

@time = POSIX::strptime("July 4", "%b %d");
is_deeply([@time[3,4]], [4, 7-1], 'strptime() partial yields correct mday/mon');

@time = POSIX::strptime("Foobar", "%H:%M:%S");
is(scalar @time, 0, 'strptime() invalid input yields empty list');

my $str;
@time = POSIX::strptime(\($str = "01:02:03"), "%H:%M:%S", -1,-1,-1, 1,0,70);
is_deeply(\@time, [3, 2, 1, 1, 0, 70, 4, 0, 0], 'strptime() parses SCALAR ref');
is(pos($str), 8, 'strptime() sets pos() magic on SCALAR ref');

$str = "Text with 2012-12-01 datestamp";
pos($str) = 10;
@time = POSIX::strptime(\$str, "%Y-%m-%d", 0, 0, 0);
is_deeply(\@time, [0, 0, 0, 1, 12-1, 2012-1900, 6, 335, 0], 'strptime() starts SCALAR ref at pos()');
is(pos($str), 20, 'strptime() updates pos() magic on SCALAR ref');

{
   # Latin-1 vs. UTF-8 strings
   my $date = "2012\x{e9}02\x{e9}01";
   utf8::upgrade my $date_U = $date;
   my $fmt = "%Y\x{e9}%m\x{e9}%d";
   utf8::upgrade my $fmt_U = $fmt;

   my @want = (undef, undef, undef, 1, 2-1, 2012-1900, 3, 31, 0);

   is_deeply([POSIX::strptime($date_U, $fmt  )], \@want, 'strptime() UTF-8 date, legacy fmt');
   is_deeply([POSIX::strptime($date,   $fmt_U)], \@want, 'strptime() legacy date, UTF-8 fmt');
   is_deeply([POSIX::strptime($date_U, $fmt_U)], \@want, 'strptime() UTF-8 date, UTF-8 fmt');

   my $str = "\x{ea} $date \x{ea}";
   pos($str) = 2;

   is_deeply([POSIX::strptime(\$str, $fmt_U)], \@want, 'strptime() legacy data SCALAR ref, UTF-8 fmt');
   is(pos($str), 12, 'pos() of legacy data SCALAR after strptime() UTF-8 fmt');

   utf8::upgrade my $str_U = $str;
   pos($str_U) = 2;

   is_deeply([POSIX::strptime(\$str_U, $fmt)], \@want, 'strptime() UTF-8 data SCALAR ref, legacy fmt');
   is(pos($str_U), 12, 'pos() of UTF-8 data SCALAR after strptime() legacy fmt');

   # High (>U+FF) strings
   my $date_UU = "2012\x{1234}02\x{1234}01";
   my $fmt_UU  = "%Y\x{1234}%m\x{1234}%d";

   is_deeply([POSIX::strptime($date_UU, $fmt_UU)], \@want, 'strptime() on non-Latin-1 Unicode');
}

eval { POSIX::strptime({}, "format") };
like($@, qr/not a reference to a mutable scalar/, 'strptime() dies on HASH ref');

eval { POSIX::strptime(\"boo", "format") };
like($@, qr/not a reference to a mutable scalar/, 'strptime() dies on const literal ref');

eval { POSIX::strptime(qr/boo!/, "format") };
like($@, qr/not a reference to a mutable scalar/, 'strptime() dies on Regexp');

$str = bless [], "WithStringOverload";
{
   package WithStringOverload;
   use overload '""' => sub { return "2012-02-01" };
}

@time = POSIX::strptime($str, "%Y-%m-%d", 0, 0, 0);
is_deeply(\@time, [0, 0, 0, 1, 2-1, 2012-1900, 3, 31, 0], 'strptime() allows object with string overload');

setlocale(LC_TIME, $orig_loc) || die "Cannot setlocale() back to orig: $!";

# clock() seems to have different definitions of what it does between POSIX
# and BSD.  Cygwin, Win32, and Linux lean the BSD way.  So, the tests just
# check the basics.
like(clock(), qr/\d*/, "clock() returns a numeric value");
cmp_ok(clock(), '>=', 0, "...and it returns something >= 0");

SKIP: {
    skip "No difftime()", 1 if $Config{d_difftime} ne 'define';
    is(difftime(2, 1), 1, "difftime()");
}

SKIP: {
    skip "No mktime()", 2 if $Config{d_mktime} ne 'define';
    my $time = time();
    is(mktime(CORE::localtime($time)), $time, "mktime()");
    is(mktime(POSIX::localtime($time)), $time, "mktime()");
}
