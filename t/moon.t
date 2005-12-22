#!/usr/bin/perl

use strict;
use warnings;

use Astro::Coord::ECI;
use Astro::Coord::ECI::Moon;
use Math::Trig;
use POSIX qw{strftime floor};
use Test;
use Time::Local;

BEGIN {plan tests => 5}
use constant EQUATORIALRADIUS => 6378.14;	# Meeus page 82.
use constant TIMFMT => '%d-%b-%Y %H:%M:%S';
use constant PI => atan2 (0, -1);

my $test = 0;


#	Tests 1 - 3: moon position in ecliptic latitude/longitude
#	and distance.
#	Tests: ::Moon->time_set() (and ecliptic())

#	This test is based on Meeus' example 47.a.

#	Meeus states that his accuracy is 10 seconds of arc in
#	longitude, and 4 seconds in latitude. He does not give
#	an accuracy on the distance.

#	Note that we're not too picky about the position of the sun, since it's
#	an extended object. One part in a thousand is less than half its disk.

foreach ([timegm (0, 0, 0, 12, 3, 1992), -3.229126, 133.167265, 368409.7],
	) {
    my ($time, $explat, $explong, $expdelta) = @$_;
##    my $moon = Astro::Coord::ECI::Moon->dynamical ($time);
    my ($lat, $long, $delta) = Astro::Coord::ECI::Moon->
	dynamical ($time)->ecliptic ();
    my $tolerance = 1e-6;
    foreach ([latitude => $lat, deg2rad ($explat)],
	    [longitude => $long, deg2rad ($explong)],
	    [distance => $delta, $expdelta],
	    ) {
	$test++;
	my ($what, $got, $expect) = @$_;
	print <<eod;
# Test $test: Ecliptic latitude/longitude and distance of the Moon
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#      Quantity: $what
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs (($got - $expect) / $expect) < $tolerance);
	}
    }

#	Test 4: phase angle of the moon.
#	Tests: phase ()

#	This test is based on Meeus' example 49.a, but worked backward.

foreach ([timegm (42, 37, 3, 18, 1, 1977), 0],
	) {
    $test++;
    my ($time, $expect) = @$_;
    $expect = deg2rad ($expect);
    my $tolerance = 1.e-4;	# A second's worth of radians.
    my $got = Astro::Coord::ECI::Moon->dynamical ($time)->phase;
    $expect += 2 * PI if $got - $expect >= PI;
    print <<eod;
# Test $test: Phase of the moon at a given time
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
    ok (abs ($got - $expect) < $tolerance);
    }

#	Test 5: next_quarter

#	This test is based on Meeus' example 49.1, right way around.

foreach ([timegm (0, 0, 0, 1, 1, 1977), 0, timegm (42, 37, 3, 18, 1, 1977)],
	) {
    $test++;
    my ($time, $quarter, $expect) = @$_;
    my $got = Astro::Coord::ECI::Moon->dynamical ($time)->
	next_quarter ($quarter);
    my $tolerance = 2;
    print <<eod;
# Test $test: Next quarter after given time.
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#       Quarter: $quarter
#      Expected: @{[strftime TIMFMT, gmtime $expect]} (dynamical)
#           Got: @{[strftime TIMFMT, gmtime $got]} (dynamical)
#     Tolerance: $tolerance seconds
eod
    ok (abs ($got - $expect) < $tolerance);
    }

__END__
