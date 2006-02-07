#!/usr/local/bin/perl

use strict;
use warnings;

use Astro::Coord::ECI::Utils qw{:all};
use POSIX qw{strftime floor};
use Test;
use Time::Local;

BEGIN {plan tests => 14}
##use constant ASTRONOMICAL_UNIT => 149_597_870; # Meeus, Appendix 1, pg 407
##use constant EQUATORIALRADIUS => 6378.14;	# Meeus page 82.
##use constant PERL2000 => timegm (0, 0, 12, 1, 0, 100);
use constant TIMFMT => '%d-%b-%Y %H:%M:%S';

my $test = 0;


#	Tests 1 - 2: Perl time to Julian days since J2000.0
#	Tests: jday2000()

#	Based on the table on Meeus' page 62.

foreach ([timegm (0, 0, 12, 1, 0, 2000), 0],
	[timegm (0, 0, 0, 1, 0, 1999), -365.5],
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

foreach ([timegm (0, 0, 12, 1, 0, 2000), 2451545.0],
	[timegm (0, 0, 0, 1, 0, 1999), 2451179.5],
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

foreach ([timegm (0, 0, 0, 10, 3, 1987), -.127296372348, '%.12f'],
	[timegm (0, 21, 19, 10, 3, 1987), -.12727430, '%.8f'],
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

foreach ([timegm (0, 0, 0, 10, 3, 1987), 11.2531],
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

foreach ([longitude => timegm (0, 0, 0, 10, 3, 1987), -3.788/3600, .5/3600],
	[obliquity => timegm (0, 0, 0, 10, 3, 1987), 9.443/3600, .1/3600],
	) {
    $test++;
    my ($what, $time, $expect, $tolerance) = @$_;
    my $method = "nutation_in_$what";
no strict qw{refs};
    my $got = $method->($time);
use strict qw{refs};
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

foreach ([timegm (0, 0, 0, 13, 9, 1992), 13 * 60 + 42.7, .1],
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

foreach ([timegm (0, 0, 0, 10, 3, 1987), (36.850 / 60 + 26) / 60 + 23],
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
