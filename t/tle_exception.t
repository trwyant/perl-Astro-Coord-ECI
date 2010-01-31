package main;

use strict;
use warnings;

use Astro::Coord::ECI::TLE;
use Time::Local;

BEGIN {

    eval {
	require Test::More;
	Test::More->import();
	1;
    } or do {
	print "1..0 # skip Test::More not available.\n";
	exit;
    };
}

my ($near, $deep) = Astro::Coord::ECI::TLE->parse(<<eod);
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    8
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  105
1 11801U          80230.29629788  .01431103  00000-0  14311-1
2 11801  46.7916 230.4354 7318036  47.4722  10.4117  2.28537848
eod

my $time = 61196688000	# 01-Apr-3909 00:00:00 GMT, epoch 1-Jan-1970.
    + timegm( 0, 0, 0, 1, 0, 70 );	# Adjust for system epoch.

my $test = 0;

plan(tests => 14);

my $want;

# SGP

$near->set(model => 'sgp');
$want = qr{effective eccentricity > 1};

eval {$near->universal($time)};
like($@, $want, 'SGP model failure.');

eval {$near->universal($time)};
like($@, $want, 'SGP should give same failure on retry.');

# SGP4

$near->set(model => 'sgp4');

eval {$near->universal($time)};
like($@, $want, 'SGP4 model failure.');

eval {$near->universal($time)};
like($@, $want, 'SGP4 should give same failure on retry.');

# SDP4

$deep->set(model => 'sdp4');

eval {$deep->universal($time)};
like($@, $want, 'SDP4 model failure.');

eval {$deep->universal($time)};
like($@, $want, 'SDP4 should give same failure on retry.');

# SGP8

$near->set(model => 'sgp8');

eval {$near->universal($time)};
like($@, $want, 'SGP8 model failure.');

eval {$near->universal($time)};
like($@, $want, 'SGP8 should give same failure on retry.');

# SDP8

$deep->set(model => 'sdp8');

eval {$deep->universal($time)};
like($@, $want, 'SDP8 model failure.');

eval {$deep->universal($time)};
like($@, $want, 'SDP8 should give same failure on retry.');

# SGP4R

$near->set(model => 'sgp4r');
$deep->set(model => 'sgp4r');
$want = qr{Mean eccentricity < 0 or > 1};

eval {$near->universal($time)};
like($@, $want, 'SGP4R model failure (near-Earth).');

eval {$near->universal($time)};
like($@, $want, 'SGP4R should give same failure on retry (near-Earth).');

eval {$deep->universal($time)};
like($@, $want, 'SGP4R model failure (deep-space).');

eval {$deep->universal($time)};
like($@, $want, 'SGP4R should give same failure on retry (deep-space).');

1;
