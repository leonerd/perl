
BEGIN {
    unless ("A" eq pack('U', 0x41)) {
	print "1..0 # Unicode::Collate " .
	    "cannot stringify a Unicode code point\n";
	exit 0;
    }
    if ($ENV{PERL_CORE}) {
	chdir('t') if -d 't';
	@INC = $^O eq 'MacOS' ? qw(::lib) : qw(../lib);
    }
}

use Test;
BEGIN { plan tests => 9 };

use strict;
use warnings;
use Unicode::Collate::Locale;

ok(1);

#########################

my $objSiDict = Unicode::Collate::Locale->
    new(locale => 'SI-dict', normalization => undef);

ok($objSiDict->getlocale, 'si__dictionary');

$objSiDict->change(level => 1);

ok($objSiDict->lt("\x{D96}", "\x{D82}"));
ok($objSiDict->lt("\x{D82}", "\x{D83}"));
ok($objSiDict->lt("\x{D83}", "\x{D9A}"));

ok($objSiDict->gt("\x{DA5}", "\x{DA2}"));
ok($objSiDict->eq("\x{DA5}", "\x{DA2}\x{DCA}\x{DA4}"));
ok($objSiDict->lt("\x{DA5}", "\x{DA3}"));

$objSiDict->change(level => 2);

ok($objSiDict->gt("\x{DA5}", "\x{DA2}\x{DCA}\x{DA4}"));

