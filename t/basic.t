package main;

use strict;
use warnings;

use Astro::Coord::ECI::Utils qw{:all};
use POSIX qw{strftime floor};
use Test;
use Time::y2038;

BEGIN {plan tests => 57}
# Perl::Critic and Perl Best Practices object to the 'constant' pragma
# because it does not interpolate. It really does, but even if not this
# is a test, and we want the script to be fairly lightweight.
## no critic ProhibitConstantPragma
##use constant ASTRONOMICAL_UNIT => 149_597_870; # Meeus, Appendix 1, pg 407
##use constant EQUATORIALRADIUS => 6378.14;	# Meeus page 82.
##use constant PERL2000 => timegm (0, 0, 12, 1, 0, 100);
use constant TIMFMT => '%d-%b-%Y %H:%M:%S';
## use critic ProhibitConstantPragma

my $test = 0;


#	Tests 1 - 2: Perl time to Julian days since J2000.0
#	Tests: jday2000()

#	Based on the table on Meeus' page 62.

foreach ([timegm (0, 0, 12, 1, 0, 100), 0],
	[timegm (0, 0, 0, 1, 0, 99), -365.5],
	) {
    $test++;
    my ($time, $expect) = @$_;
    my $got = jday2000 ($time);
    print <<eod;
# Test $test: convert time to days since Julian 2000.0
#     Universal: @{[strftime TIMFMT, gmtime $time]}
#      Expected: $expect
#           Got: $got
eod
    ok ($expect == $got);
    }


#	Tests 3 - 4: Perl time to Julian day
#	Tests: julianday()

#	Based on the table on Meeus' page 62.

foreach ([timegm (0, 0, 12, 1, 0, 100), 2451545.0],
	[timegm (0, 0, 0, 1, 0, 99), 2451179.5],
	) {
    $test++;
    my ($time, $expect) = @$_;
    my $got = julianday ($time);
    print <<eod;
# Test $test: convert time to Julian day
#     Universal: @{[strftime TIMFMT, gmtime $time]}
#      Expected: $expect
#           Got: $got
eod
    ok ($expect == $got);
    }


#	Tests 5 - 6: Perl time to Julian centuries since J2000.0
#	Tests: jcent2000()

#	Based on Meeus' examples 12.a and 12.b.

foreach ([timegm (0, 0, 0, 10, 3, 87), -.127296372348, '%.12f'],
	[timegm (0, 21, 19, 10, 3, 87), -.12727430, '%.8f'],
	) {
    $test++;
    my ($time, $expect, $tplt) = @$_;
    my $got = jcent2000 ($time);
    my $check = sprintf $tplt, $got;
    print <<eod;
# Test $test: convert time to Julian centuries since Julian 2000.0
#     Universal: @{[strftime TIMFMT, gmtime $time]}
#      Expected: $expect
#           Got: $got
eod
    ok ($expect == $check);
    }


#	Tests 7 - 8: thetag
#	Tests: thetag()

#	Based on Meeus' examples 12a and 12b, pages 88 and 89.

foreach ([timegm (0, 0, 0, 10, 3, 87), 3.450397161537],
	[timegm (0, 21, 19, 10, 3, 87), 2.246899761682]) {

    $test++;
    my ($time, $expect) = @$_;
    my $tolerance = 1e-6;
    my $got = thetag ($time);
    print <<eod;
# Test $test: Hour angle of Greenwich (Thetag)
#     Universal: @{[strftime TIMFMT, gmtime $time]}
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
    ok (abs (($got - $expect) / $expect) < $tolerance);
    }


#	Test 9: theta0

#	Based on Meeus' examples 12a and 12b, pages 88 and 89.
#	Tests: theta0()

foreach ([timegm (0, 21, 19, 10, 3, 87), 3.450397161537]) {

    $test++;
    my ($time, $expect) = @$_;
    my $tolerance = 1e-6;
    my $got = theta0 ($time);
    print <<eod;
# Test $test: Hour angle of Greenwich at 0 UT (Theta0)
#     Universal: @{[strftime TIMFMT, gmtime $time]}
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
    ok (abs (($got - $expect) / $expect) < $tolerance);
    }


#	Test 10: Ecliptic longitude of ascending node of moon's mean
#	orbit.
#	Tests: omega (and jcent2000).

#	Based on Meeus' example 22.a.

foreach ([timegm (0, 0, 0, 10, 3, 87), 11.2531],
	) {
    $test++;
    my ($time, $expect) = @$_;
    my $got = omega ($time);
    $expect = deg2rad ($expect);
    my $tolerance = 1.e-5;
    print <<eod;
# Test $test: Ecliptic longitude of Moon's mean ascending node
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
    ok (abs (($got - $expect) / $expect) < $tolerance);
    }


#	Tests 11-12: Nutation in longitude and obliquity.
#	Tests: nutation_in_longitude, nutation_in_obliquity (and
#		jcent2000).

#	Based on Meeus' example 22.a.

foreach ([longitude => timegm (0, 0, 0, 10, 3, 87), -3.788/3600, .5/3600],
	[obliquity => timegm (0, 0, 0, 10, 3, 87), 9.443/3600, .1/3600],
	) {
    $test++;
    my ($what, $time, $expect, $tolerance) = @$_;
    my $method = Astro::Coord::ECI::Utils->can("nutation_in_$what");
    my $got = $method->($time);
    $expect = deg2rad ($expect);
    $tolerance = deg2rad ($tolerance);
    print <<eod;
# Test $test: Nutation in $what
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
    ok (abs ($got - $expect) < $tolerance);
    }


#	Test 13: Equation of time.
#	Tests: equation_of_time() (and obliquity()).

#	This test is based on Meeus' example 28.b.

foreach ([timegm (0, 0, 0, 13, 9, 92), 13 * 60 + 42.7, .1],
	) {
    my ($time, $expect, $tolerance) = @$_;
    my $got = equation_of_time ($time);
    $test++;
    print <<eod;
# Test $test: Equation of time
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#      Expected: $expect seconds
#           Got: $got seconds
#     Tolerance: $tolerance seconds
eod
    my $tplt = "%${tolerance}f";
    ok (sprintf ($tplt, $expect) == sprintf ($tplt, $got));
    }



#	Test 14: Obliquity of the ecliptic.
#	Tests: obliquity() (and nutation_in_obliquity() and
#		jcent2000())

#	Based on Meeus' example 22.a.

foreach ([timegm (0, 0, 0, 10, 3, 87), (36.850 / 60 + 26) / 60 + 23],
	) {
    $test++;
    my ($time, $expect) = @$_;
    my $got = obliquity ($time);
    $expect = deg2rad ($expect);
    my $tolerance = 1e-6;
    print <<eod;
# Test $test: Obliquity of the ecliptic
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
    ok (abs (($got - $expect) / $expect) < $tolerance);
    }


#	Test 15: Light intensity to magnitude.
#	Tests: intensity_to_magnitude

#	Based on Meeus' example 56.e.

foreach ([500, -6.75, 0.01]) {
    $test++;
    my ($ratio, $expect, $tolerance) = @$_;
    my $got = intensity_to_magnitude ($ratio);
    print <<eod;
# Test $test: Light intensity to magnitude
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
    ok (abs ($got - $expect) <= $tolerance);
    }

#	Tests 16 - 18: Atmospheric extinction
#	Tests: atmospheric_extinction

#	Based on Green's extinction table 1a

foreach ([80, 0, 1.59], [45, .5, 0.34], [1, 1, 0.21]) {
    $test++;
    my ($Z, $height, $expect) = @$_;
    my $elevation = deg2rad (90 - $Z);
    my $got = atmospheric_extinction ($elevation, $height);
    print <<eod;
# Test $test: Atmospheric extinction
#    Conditions: Z = $Z, height = $height
#      Expected: $expect
#           Got: $got
eod
    ok (abs ($got - $expect) <= .01);
    }

# Tests 19 -  : Julian dates

#	Based on Meeus pp60ff

foreach (
    [date2jd => [
	4.81,
	9,
	57,		# 1957
    ], [jd => 2436116.31]],
    [date2jd => [
	12,
	27,
	0,
	-1567,		# 333
    ], [jd => 1842713.0]],
    [jd2date => [2436116.31], [
	day => 4.81,
	mon => 9,
	yr => 57,	# 1957
    ]],
    [jd2date => [1842713.0], [
	day => 27.5,
	mon => 0,
	yr => -1567,	# 333
    ]],
    [jd2date => [1507900.13], [
	day => 28.63,
	mon => 4,
	yr => -2484,	# -584
    ]],
    [date2epoch => [
	12,
	1,
	0,
	100,		# 2000
    ], [epoch => PERL2000]],
    [epoch2datetime => [PERL2000], [
	sec => 0,
	min => 0,
	hr => 12,
	day => 1,
	mon => 0,
	yr => 100,	# 2000
    ]],
    [jd2datetime => [2434923.5], [	# Meeus example 7.e.
	sec => 0,
	min => 0,
	hr => 0,
	day => 30,
	mon => 5,
	yr => 54,	# 1954
	wday => 3,	# Wednesday
    ]],
    [jd2datetime => [2443826.5], [	# Meeus example 7.f.
	sec => 0,
	min => 0,
	hr => 0,
	day => 14,
	mon => 10,
	yr => 78,	# 1978
	wday => undef,	# Not specified in example.
	yday => 317,	# 1 less because 0-based.
    ]],
    [jd2datetime => [2447273.5], [	# Meeus example 7.g.
	sec => 0,
	min => 0,
	hr => 0,
	day => 22,
	mon => 3,
	yr => 88,	# 1978
	wday => undef,	# Not specified in example.
	yday => 112,	# 1 less because 0-based.
    ]],
) {
    my ($method, $args, $want) = @$_;
    my @want = @$want;
    my $items = @want / 2;
    my $code = Astro::Coord::ECI::Utils->can ($method)
	or die "Fatal - Astro::Coord::ECI::Utils::'$method' not found";
    print <<eod;
#
# Testing $method (@{[join ', ', @$args]})
eod
    my @got = $code->(@$args);
    @got > $items and splice @got, $items;
    foreach my $got (@got) {
	my $name = shift @want;
	defined (my $want = shift @want) or next;
	my $tolerance = $want;
	$tolerance =~ s/\.$//;
	if ($want =~ m/\./) {
	    $tolerance =~ s/.*\././;
	    $tolerance =~ s/\d/0/g;
	    $tolerance =~ s/0$/1/;
	} else {
	    $tolerance = 1;
	}
	$tolerance /= 2;
	$test++;
	print <<eod;
#
# Test $test - $method output $name
#      Expected: $want
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs ($want - $got) <= $tolerance);
    }
}

1;
