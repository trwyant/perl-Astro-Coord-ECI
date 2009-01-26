package main;

use strict;
use warnings;

use Astro::Coord::ECI::TLE;
use Test;

BEGIN {
    eval {
	require Time::y2038;
	Time::y2038->import();
	1;
    } or do {
	require Time::Local;
	Time::Local->import();
    };
}

my ($near, $deep) = Astro::Coord::ECI::TLE->parse(<<eod);
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    8
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  105
1 11801U          80230.29629788  .01431103  00000-0  14311-1
2 11801  46.7916 230.4354 7318036  47.4722  10.4117  2.28537848
eod

my $time = timegm(0, 0, 0, 1, 3, 2009);
my $test = 0;


plan(tests => 14);

my ($got, $want);

# SGP

$near->set(model => 'sgp');
$want = qr{Effective eccentricity > 1};

eval {$near->universal($time)};
$got = $@;
test($got, $want, 'SGP model failure.');

eval {$near->universal($time)};
$got = $@;
test($got, $want, 'SGP should give same failure on retry.');

# SGP4

$near->set(model => 'sgp4');
$want = qr{Effective eccentricity > 1};

eval {$near->universal($time)};
$got = $@;
test($got, $want, 'SGP4 model failure.');

eval {$near->universal($time)};
$got = $@;
test($got, $want, 'SGP4 should give same failure on retry.');

# SDP4

$deep->set(model => 'sdp4');
$want = qr{Effective eccentricity > 1};

eval {$deep->universal($time)};
$got = $@;
test($got, $want, 'SDP4 model failure.');

eval {$deep->universal($time)};
$got = $@;
test($got, $want, 'SDP4 should give same failure on retry.');

# SGP8

$near->set(model => 'sgp8');
$want = qr{Effective eccentricity > 1};

eval {$near->universal($time)};
$got = $@;
test($got, $want, 'SGP8 model failure.');

eval {$near->universal($time)};
$got = $@;
test($got, $want, 'SGP8 should give same failure on retry.');

# SDP8

$deep->set(model => 'sdp8');
$want = qr{Effective eccentricity > 1};

eval {$deep->universal($time)};
$got = $@;
test($got, $want, 'SDP8 model failure.');

eval {$deep->universal($time)};
$got = $@;
test($got, $want, 'SDP8 should give same failure on retry.');

# SGP4R

$near->set(model => 'sgp4r');
$deep->set(model => 'sgp4r');
$want = qr{Mean eccentricity < 0 or > 1};

eval {$near->universal($time)};
$got = $@;
test($got, $want, 'SGP4R model failure (near-Earth).');

eval {$near->universal($time)};
$got = $@;
test($got, $want, 'SGP4R should give same failure on retry (near-Earth).');

eval {$deep->universal($time)};
$got = $@;
test($got, $want, 'SGP4R model failure (deep-space).');

eval {$deep->universal($time)};
$got = $@;
test($got, $want, 'SGP4R should give same failure on retry (deep-space).');

# Subroutines

sub groom {
    my $in = shift;
    if ($in =~ m/\n/sm) {
	return join('',
	    "<<eod\n",
	    (map {"# $_\n"} split qr{\n}sm, $got),
	    "# eod");
    } else {
	$in =~ s/([\\'])/\\$1/gsm;
	return "'$in'";
    }
}

sub test {
    my ($got, $want, $title) = @_;
    my ($got_disp, $want_disp);
    chomp $got;
    $got_disp = groom($got);
    if (ref $want) {
	$want_disp = $want;
    } else {
	chomp $want;
	$want_disp = groom($want);
    }
    $test++;
    print <<eod;
#
# Test $test: $title
#      Got: $got_disp
# Expected: $want_disp
eod
    if (ref $want eq 'Regexp') {
	ok($got =~ m/$want/);
    } else {
	ok($got eq $want);
    }
    return;
}


1;
