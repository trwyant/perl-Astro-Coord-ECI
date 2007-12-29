use strict;
use warnings;

use Astro::Coord::ECI;
use Astro::Coord::ECI::Sun;
use Astro::Coord::ECI::Utils qw{deg2rad};
use POSIX qw{strftime floor};
use Test;
use Time::Local;

BEGIN {plan tests => 21}
use constant EQUATORIALRADIUS => 6378.14;	# Meeus page 82.
use constant TIMFMT => '%d-%b-%Y %H:%M:%S';

my $test = 0;


#	Tests 1 - 3: sun position in ecliptic latitude/longitude
#	Tests: ::Sun->time_set() (and ecliptic())

#	This test is based on Meeus' example 25.a.

#	Note that we're not too picky about the position of the sun, since it's
#	an extended object. One part in a thousand is less than half its disk.

use constant ASTRONOMICAL_UNIT => 149_597_870; # Meeus, Appendix 1, pg 407

foreach ([timegm (0, 0, 0, 13, 9, 1992), 199.90895, .99766, 199.90988],
	) {
    my ($time, $explong, $exprho, $expgeo) = @$_;
    my $sun = Astro::Coord::ECI::Sun->dynamical ($time);
    my ($lat, $long, $rho) = $sun->ecliptic ();
    my $tolerance = 1e-5;
    foreach ([longitude => $long, deg2rad ($explong)],
	    [distance => $rho, $exprho * ASTRONOMICAL_UNIT],
	    ['geometric longitude' => $sun->geometric_longitude(), deg2rad ($expgeo)],
	    ) {
	$test++;
	my ($what, $got, $expect) = @$_;
	print <<eod;
# Test $test: Ecliptic latitude/longitude of the sun
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#      Quantity: $what
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs (($got - $expect) / $expect) < $tolerance);
	}
    }



#	Tests 4 - 15: Sunrise, noon, and sunset
#	Tests: next_meridian (), next_elevation ()

#	This test is based on data for Washington, DC provided by the
#	U.S. Naval Observatory, available from http://aa.usno.navy.mil/
#	The dates are the equinoxes and solstices for 2005 (same
#	source), and the location is Washington, DC (same source). Note
#	that times are computed in U.T. and then hand-converted to zone
#	-5. We don't simply use localtime() since we don't know that
#	the test script is being run in zone -5. This kind of argues
#	for the use of DateTime, but I don't understand their
#	leap-second code well enough yet.

foreach ([timegm (0, 0, 0, 20, 2, 2005), 53/60 + 38, -(2/60 + 77), -5,
		timegm (0, 11, 6, 20, 2, 2005),
		timegm (0, 16, 12, 20, 2, 2005),
		timegm (0, 20, 18, 20, 2, 2005)],
	[timegm (0, 0, 0, 21, 5, 2005), 53/60 + 38, -(2/60 + 77), -5,
		timegm (0, 43, 4, 21, 5, 2005),
		timegm (0, 10, 12, 21, 5, 2005),
		timegm (0, 37, 19, 21, 5, 2005)],
	[timegm (0, 0, 0, 22, 8, 2005), 53/60 + 38, -(2/60 + 77), -5,
		timegm (0, 56, 5, 22, 8, 2005),
		timegm (0, 1, 12, 22, 8, 2005),
		timegm (0, 5, 18, 22, 8, 2005)],
	[timegm (0, 0, 0, 21, 11, 2005), 53/60 + 38, -(2/60 + 77), -5,
		timegm (0, 23, 7, 21, 11, 2005),
		timegm (0, 6, 12, 21, 11, 2005),
		timegm (0, 50, 16, 21, 11, 2005)],
	) {
    my ($time, $lat, $long, $zone, $exprise, $expnoon, $expset) = @$_;
    my $date = strftime '%d-%b-%Y', gmtime $time;
    $time -= $zone * 3600;
    my $sta = Astro::Coord::ECI->new (refraction => 1)->
	universal ($time)->
	geodetic (deg2rad ($lat), deg2rad ($long), 0);
    my $sun = Astro::Coord::ECI::Sun->new ();
    my $rise = $sta->next_elevation ($sun, 0, 1);
    my $noon = $sta->next_meridian ($sun);
    my $set = $sta->next_elevation ($sun, 0, 1);
    my $tolerance = 30;	# seconds
    foreach ([sunrise => $rise, $exprise],
		[noon => $noon, $expnoon],
		[sunset => $set, $expset]) {
	$test++;
	my ($what, $got, $expect) = @$_;
	$got += $zone * 3600;
	print <<eod;
# Test $test: @{[ucfirst $what]} at latitude @{[sprintf '%.4f', $lat
	]} degrees, longitude @{[sprintf '%.4f', $long]} degrees
#          Date: $date
#      Expected: @{[strftime TIMFMT, gmtime $expect]} (Eastern Standard)
#           Got: @{[strftime TIMFMT, gmtime $got]} (Eastern Standard)
#     Tolerance: $tolerance seconds
eod
	ok (abs ($got - $expect) <= $tolerance);
	}
    }

#	Tests 16 - 19: Equinoxes and Solstices for 2005
#	Tests: next_quarter()

#	This test is based on Meeus' table 27.E on page 182. The
#	accuracy is a fairly poor 16 minutes 40 seconds, because
#	our  position of the Sun is only good to 0.01 degrees.

foreach ([timegm (0, 0, 0, 1, 0, 2005),
		timegm (29, 34, 12, 20, 2, 2005),
		timegm (12, 47, 6, 21, 5, 2005),
		timegm (14, 24, 22, 22, 8, 2005),
		timegm (01, 36, 18, 21, 11, 2005)],
	) {
    my $year = (gmtime $_->[0])[5] + 1900;
    my $sun = Astro::Coord::ECI::Sun->universal (shift @$_);
    my $tolerance = 16 * 60 + 40;
    foreach my $expect (@$_) {
	$test++;
	my ($got, undef, $quarter) = $sun->next_quarter;
	$got = $sun->dynamical;
	print <<eod;
# Test $test: $quarter $year
#      Expected: @{[strftime TIMFMT, gmtime $expect]} (dynamical)
#           Got: @{[strftime TIMFMT, gmtime $got]} (dynamical)
#     Tolerance: $tolerance seconds
eod
	ok (abs ($got - $expect) <= $tolerance);
	}
    }

#	Tests 20 - 21: Singleton object

{	# Local symbol block.
    my $skip;
    eval {
	local $@;
	$skip = "Can not load Scalar::Util.";
	require Scalar::Util;
	$skip = "Scalar::Util does not implement refaddr ().";
	UNIVERSAL::can ('Scalar::Util', 'refaddr')
	    and $skip = undef;
    };
    my @text = qw{different same};

    foreach ([1, 1], [0, 0]) {
	my ($sgl, $expect) = @$_;
	my $got =  do {
	    local $Astro::Coord::ECI::Sun::Singleton = $sgl;
	    my @sun = map {Astro::Coord::ECI::Sun->new} (0 .. 1);
	    Scalar::Util::refaddr ($sun[0]) ==
		Scalar::Util::refaddr ($sun[1]) ? 1 : 0;
	    } unless $skip;
	$test++;
	print <<eod;
# Test $test: \$Astro::Coord::ECI::Sun::Singleton = $sgl
#      Expected: $text[$expect]
#           Got: @{[$skip ? 'skipped' : $text[$got]]}
eod
	skip ($skip, $skip || $got eq $expect);
	}
    }
