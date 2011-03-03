package main;

use strict;
use warnings;

use Astro::Coord::ECI;
use Astro::Coord::ECI::Utils qw{ :time deg2rad PERL2000 rad2deg };
use POSIX qw{strftime floor};
use Test;

BEGIN {plan tests => 72}

use constant EQUATORIALRADIUS => 6378.14;	# Meeus page 82.
use constant TIMFMT => '%d-%b-%Y %H:%M:%S';

Astro::Coord::ECI->set (debug => 0);

my $test = 0;

#	Tests 1 - 2: universal time
#	Tests: universal()

#	We just make sure we get the same thing back.

foreach ([timegm (0, 0, 0, 1, 0, 100)],
	[timegm (0, 0, 0, 1, 0, 105)],
	) {
    $test++;
    my ($expect) = @$_;
    my $univ =
	Astro::Coord::ECI->universal ($expect)->universal;
    print <<eod;
# Test $test: storage and retrieval of universal time
#        Stored: @{[strftime TIMFMT, gmtime $expect]}
#           Got: @{[strftime TIMFMT, gmtime $univ]}
eod
    ok ($expect == $univ);
    }


#	Tests 3 - 4: universal time -> dynamical time
#	Tests: dynamical()

foreach ([timegm (0, 0, 0, 1, 0, 100), 65],
	[timegm (0, 0, 0, 1, 0, 105), 72],
	) {
    $test++;
    my ($univ, $expect) = @$_;
    $expect += $univ;
    my $dyn = floor (
	Astro::Coord::ECI->universal ($univ)->dynamical + .5);
    print <<eod;
# Test $test: convert universal time to dynamical time.
#     Universal: @{[strftime TIMFMT, gmtime $univ]}
#      Expected: @{[strftime TIMFMT, gmtime $expect]}
#           Got: @{[strftime TIMFMT, gmtime $dyn]}
eod
    ok ($expect == $dyn);
    }


#	Tests 5 - 6: dynamical time -> universal time
#	tests: dynamical()

foreach ([timegm (0, 0, 0, 1, 0, 100), -65],
	[timegm (0, 0, 0, 1, 0, 105), -72],
	) {
    $test++;
    my ($dyn, $expect) = @$_;
    $expect += $dyn;
    my $univ = floor (
	Astro::Coord::ECI->dynamical ($dyn)->universal + .5);
    print <<eod;
# Test $test: convert dynamical time to universal time.
#     Dynamical: @{[strftime TIMFMT, gmtime $dyn]}
#      Expected: @{[strftime TIMFMT, gmtime $expect]}
#           Got: @{[strftime TIMFMT, gmtime $univ]}
eod
    ok ($expect == $univ);
    }


#	Tests 7 - 9: ecef
#	Tests: ecef()

#	All we do here is be sure we get back what we put in.

foreach ([3000, 4000, 5000]) {
    my ($x, $y, $z) = @$_;
    my ($X, $Y, $Z) = Astro::Coord::ECI->ecef ($x, $y, $z)->ecef ();
    foreach ([X => $X, $x], [Y => $Y, $y], [Z => $Z, $z]) {
	$test++;
	my ($axis, $got, $expect) = @$_;
	print <<eod;
# Test $test: Geocentric ecef coordinates.
#          Axis: $axis
#      Expected: $expect
#           Got: $got
eod
	ok ($expect == $got);
	}
    }


#	Tests 10 - 13: geodetic -> geocentric
#	Tests: geodetic()

#	Meeus, page 82, example 11a

#	Both TopoZone and Google say the observatory is
#	latitude 34 deg 13'33" N (=   degrees),
#	longitude 118 deg 03'25" W (= -118.056944444444 degrees).
#	The test uses Meeus' latitude of 33 deg 21'22" N (since
#	that's what Meeus himself uses) but the TopoZone/Google
#	value for longitude, since longitude does not affect the
#	calculation, but my Procrustean validation expects it.

#	We also test the antpodal (sort of) point, since finding a bug
#	in my implementation of Borkowski's algorithm when running on
#	a point in the southern hemisphere. No, this particular test
#	doesn't use that algorithm, but once bitten, twice shy.

foreach ([IAU76 => .58217396455, -2.060487233536, 1.706, .546861, .836339, '%.6f'],
	[IAU76 => -.58217396455, 2.060487233536, 1.706, -.546861, .836339, '%.6f'],
	) {
    my ($elps, $lat, $long, $elev, $expsin, $expcos, $tplt) = @$_;
##  my ($phiprime, $theta, $rho) =
    my ($phiprime, undef, $rho) =
	Astro::Coord::ECI->new (ellipsoid => $elps)->
	geodetic ($lat, $long, $elev)->geocentric;
    my $rhosinphiprime = $rho / EQUATORIALRADIUS * sin ($phiprime);
    my $rhocosphiprime = $rho / EQUATORIALRADIUS * cos ($phiprime);
    foreach (['rho * sin (phiprime)' => $rhosinphiprime, $expsin],
	['rho * cos (phiprime)' => $rhocosphiprime, $expcos]) {
	$test++;
	my ($what, $got, $expect) = @$_;
	print <<eod;
# Test $test: Geocentric to geodetic
#      Quantity: $what
#      Expected: $expect
#           Got: $got
eod
	ok ($expect == sprintf $tplt, $got);
	}
    }


#	Tests 14 - 19: geocentric -> geodetic
#	Tests: geodetic()

#	Borkowski
#	For this, we just invert Meeus' example.

#	We also test the antpodal point, since finding a bug in my
#	implementation of Borkowski's algorithm when running on a point
#	in the southern hemisphere.

foreach ([IAU76 => 0.579094339305825, -2.060487233536, 6373.41803380646,
		[.58217396455, 1e-6], [-2.060487233536, 1e-6], [1.706, 1e-3]],
	[IAU76 => -0.579094339305825, 1.08110542005979, 6373.41803380646,
		[-.58217396455, 1e-6], [1.08110542005979, 1e-6], [1.706, 1e-3]],
	) {
    my ($elps, $phiprime, $theta, $rho, $explat, $explon, $expele) = @$_;
    my ($lat, $long, $elev) =
	Astro::Coord::ECI->new (ellipsoid => $elps)->
	geocentric ($phiprime, $theta, $rho)->geodetic;
    foreach ([latitude => $lat, @$explat],
    	    [longitude => $long, @$explon],
    	    ['elevation above mean sea level' => $elev, @$expele],
    	    ) {
	$test++;
	my ($what, $got, $expect, $tolerance) = @$_;
	print <<eod;
# Test $test: Geodetic to geocentric
#      Quantity: $what
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs (($got - $expect) / $expect) < $tolerance);
	}
    }


#	Tests 20 - 25: geodetic -> Earth-Centered, Earth-Fixed
#	Tests: geocentric() (and geodetic())

#	Continuing the above example, but ecef coordinates. Book
#	answer from http://www.ngs.noaa.gov/cgi-bin/xyz_getxyz.prl is
#    x                y             z       Elipsoid
# -2508975.4549 -4707403.8939  3487953.2711 GRS80

print <<eod;
#
# In the following twelve tests the tolerance is degraded because the
# book solution is calculated using a different, and apparently
# simpler model attributed to Escobal, "Methods of Orbit
# Determination", 1965, Wiley & Sons, Inc., pp. 27-29.
#
eod

foreach ([GRS80 => .58217396455, -2.060487233536, 1.706,
		-2508.9754549, -4707.4038939, 3487.9532711, 1e-5],
	[GRS80 => -.58217396455, 1.08110542005979, 1.706,
		2508.9754549, 4707.4038939, -3487.9532711, 1e-5],
	) {
    my ($elps, $lat, $long, $elev, $expx, $expy, $expz, $tolerance) = @$_;
    my ($x, $y, $z) =
	Astro::Coord::ECI->new (ellipsoid => $elps)->
	geodetic ($lat, $long, $elev)->ecef;
    foreach ([x => $x, $expx], [y => $y, $expy], [z => $z, $expz]) {
	$test++;
	my ($what, $got, $expect) = @$_;
	print <<eod;
# Test $test: Geodetic to Earth-Centered, Earth-Fixed
#      Quantity: $what
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs (($got - $expect) / $expect) < $tolerance);
	}
    }


#	Tests 26 - 31: Earth-Centered, Earth-Fixed -> geodetic
#	Tests: geocentric() (and geodetic())

#	Continuing the above example, but ecef coordinates. We use
#	the book solution of the opposite test as our input, and
#	vice versa.

foreach ([GRS80 => -2508.9754549, -4707.4038939, 3487.9532711,
		.58217396455, -2.060487233536, 1.706, 1e-5],
	[GRS80 => 2508.9754549, 4707.4038939, -3487.9532711,
		-.58217396455, 1.08110542005979, 1.706, 1e-5],
	) {
    my ($elps, $x, $y, $z, $explat, $explong, $expelev, $tolerance) = @$_;
    my ($lat, $long, $elev) =
	Astro::Coord::ECI->new (ellipsoid => $elps)->
	ecef ($x, $y, $z)->geodetic;
    foreach ([latitude => $lat, $explat],
		[longitude => $long, $explong],
		[elevation => $elev, $expelev],
		) {
	$test++;
	my ($what, $got, $expect) = @$_;
	print <<eod;
# Test $test: Earth-Centered, Earth-Fixed to Geodetic
#      Quantity: $what
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs (($got - $expect) / $expect) < $tolerance);
	}
    }


#	Tests 32 - 37: geodetic -> eci
#	Tests: eci() (and geodetic() and geocentric())

#	Standard is from http://celestrak.com/columns/v02n03/ (Kelso)

foreach ([WGS72 => deg2rad (40), deg2rad (-75), 0,
		timegm (0, 0, 9, 1, 9, 95), 1703.295, 4586.650, 4077.984],
	[WGS72 => deg2rad (-40), deg2rad (-75 + 180), 0,
		timegm (0, 0, 9, 1, 9, 95), -1703.295, -4586.650, -4077.984],
	) {
    my ($elps, $lat, $long, $elev, $time, $expx, $expy, $expz) = @$_;
    my ($x, $y, $z) =
	Astro::Coord::ECI->new (ellipsoid => $elps)->
	geodetic ($lat, $long, $elev)->eci ($time);
    my $tolerance = 1e-6;
    foreach ([x => $x, $expx], [y => $y, $expy], [z => $z, $expz]) {
	$test++;
	my ($what, $got, $expect) = @$_;
	print <<eod;
# Test $test: Geodetic to ECI
#      Quantity: $what
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs (($got - $expect) / $expect) < $tolerance);
	}
    }


#	Tests 38 - 43: eci -> geodetic
#	Tests: eci() (and geodetic() and geocentric())

#	This is the reverse of the previous test.

foreach ([WGS72 => 1703.295, 4586.650, 4077.984,
		timegm (0, 0, 9, 1, 9, 95),
		deg2rad (40), deg2rad (-75), 0],
	[WGS72 => -1703.295, -4586.650, -4077.984,
		timegm (0, 0, 9, 1, 9, 95),
		deg2rad (-40), deg2rad (-75 + 180), 0],
	) {
    my ($elps, $x, $y, $z, $time, $explat, $explong, $expelev) = @$_;
    my ($lat, $long, $elev) =
	Astro::Coord::ECI->new (ellipsoid => $elps)->
	eci ($x, $y, $z, $time)->geodetic;
    my $tolerance = 1e-6;
    foreach ([latitude => $lat, $explat],
		[longitude => $long, $explong],
		['elevation + equatorial radius' =>
			$elev + EQUATORIALRADIUS,
			$expelev + EQUATORIALRADIUS],
		) {
	$test++;
	my ($what, $got, $expect) = @$_;
	print <<eod;
# Test $test: Geodetic to ECI
#      Quantity: $what
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs (($got - $expect) / $expect) < $tolerance);
	}
    }


#	Tests 44 - 46: azel
#	Tests: azel() (and geodetic(), geocentric(), and eci())

#	Book solution from
#	http://www.satcom.co.uk/article.asp?article=1

print <<eod;
#
# In the following three tests the tolerance is degraded because the
# book solution is calculated by http://www.satcom.co.uk/article.asp?article=1
# which apparently assumes an exactly synchronous orbit. Their exact
# altitude assumption is undocumented, as is their algorithm. So the
# tests are really more of a sanity check.
#
eod

foreach ([GRS80 => 38, -80, 1, 0, -75, 35800,
		timegm (0, 0, 5, 27, 7, 105),
		45.682, 171.906, 37355.457],
	) {
    my ($elps, $olat, $olong, $oelev,
	$slat, $slong, $selev,
	$time,
	$expalt, $expazm, $exprng) = @$_;
print <<eod;
# Debug - reference ellipsoid = '$elps'
eod
    my ($azm, $elev, $rng) =
	Astro::Coord::ECI->new (ellipsoid => $elps)->
	geodetic (deg2rad ($olat), deg2rad ($olong), $oelev)->
	azel (
	    Astro::Coord::ECI->new (ellipsoid => $elps)->
	    universal ($time)->
	    geodetic (deg2rad ($slat), deg2rad ($slong), $selev)
	    );
    my $tolerance = 1e-3;
    foreach ([altitude => $elev, deg2rad ($expalt)],
		[azimuth => $azm, deg2rad ($expazm)],
		[range => $rng, $exprng],
		) {
	$test++;
	my ($what, $got, $expect) = @$_;
	print <<eod;
# Test $test: altitude/azimuth for observer
#      Quantity: $what
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs (($got - $expect) / $expect) < $tolerance);
	}
    }


#	Test 47: atmospheric refraction.
#	Tests: correct_for_refraction()

#	Based on Meeus' Example 16.a.

foreach ([.5541, 57.864]) {
    $test++;
    my ($elev, $expect) = @$_;
    my $got = Astro::Coord::ECI->
	correct_for_refraction (deg2rad ($elev));
    $expect = deg2rad ($expect / 60);
    my $tolerance = 1e-4;
    print <<eod;
# Test $test: correction for atmospheric refraction
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
    ok (abs (($got - $expect) / $expect) < $tolerance);
    }


#	Test 48: Angle between two points as seen from a third.
#	Tests: angle.

foreach ([[0, 0, 0], [1, 0, 0], [0, 1, 0], 90],
	) {
    $test++;
    my ($A, $B, $C, $expect) = @$_;
    foreach ($A, $B, $C) {
	$_ = Astro::Coord::ECI->ecef (@$_);
	}
    $expect = deg2rad ($expect);
    my $tolerance = 1e-6;
    my $got = $A->angle ($B, $C);
    print <<eod;
# Test $test: Angle between two points as seen from a third
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
    ok (abs ($got - $expect) < $tolerance);
    }


#	Tests 49-50: Precession of equinoxes.
#	Tests: precession.

#	Based on Meeus' example 21.b.

use constant LIGHTYEAR2KILOMETER => 9.4607e12;

foreach ([41.054063, 49.227750, 36.64, PERL2000, 41.547214, 49.348483,
		timegm (0, 0, 0, 13, 10, 128) + .19 * 86400],
	) {
    my ($alpha0, $delta0, $rho, $t0, $alphae, $deltae, $time) = @$_;
    my $eci = Astro::Coord::ECI->dynamical ($t0)->equatorial (
	deg2rad ($alpha0), deg2rad ($delta0),
	$rho *  LIGHTYEAR2KILOMETER)->set (equinox_dynamical => $t0);
    my $utim = Astro::Coord::ECI->dynamical ($time)->universal;
    my ($alpha, $delta) = $eci->precess ($utim)->equatorial ();
    my $tolerance = 1e-6;
    foreach (['right ascension' => $alpha, $alphae],
	    [declination => $delta, $deltae],
	    ) {
	my ($what, $got, $expect) = @$_;
	$got = rad2deg ($got);
	$test++;
	print <<eod;
# Test $test: Precession of equinoxes
#      Expected: $expect degrees $what
#           Got: $got degrees $what
#     Tolerance: $tolerance
eod
	ok (abs ($got - $expect) < $tolerance);
	}
    }


#	Test 51 - 52: Right ascension/declination to ecliptic lat/lon
#	Tests: ecliptic() (and obliquity())

#	Based on Meeus' example 13.a, page 95.

#	Meeus' example involves the star Pollux. We use an arbitrary
#	(and much too small) rho, because it doesn't come into the
#	conversion anyway. The time matters because it figures in to
#	the obliquity of the ecliptic. Unfortunately Meeus didn't give
#	us the time in his example, only the obliquity. The time used
#	in the example was chosen because it gave the desired obliquity
#	value of 23.4392911 degrees.

foreach ([116.328942, 28.026183, 6.684170, 113.215630,
	    timegm (36, 27, 2, 30, 6, 109)],
	) {
    my ($ra, $dec, $explat, $explong, $time) = @$_;
    my ($lat, $long) = Astro::Coord::ECI->equatorial (
	deg2rad ($ra), deg2rad ($dec), 1e12, $time)->ecliptic;
    my $tolerance = 1e-6;
    foreach ([latitude => $lat, deg2rad ($explat)],
		[longitude => $long, deg2rad ($explong)],
		) {
	$test++;
	my ($what, $got, $expect) = @$_;
	print <<eod;
# Test $test: Right ascension/declination to ecliptic latitude/longitude
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#      Quantity: $what
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs (($got - $expect) / $expect) < $tolerance);
	}
    }


#	Test 53 - 54: Ecliptic lat/lon to right ascension/declination
#	Tests: ecliptic() (and obliquity())

#	Based on inverting the above test.

foreach ([6.684170, 113.215630, 116.328942, 28.026183,
	    timegm (36, 27, 2, 30, 6, 109)],
	) {
    my ($lat, $long, $expra, $expdec, $time) = @$_;
    my ($ra, $dec) = Astro::Coord::ECI->ecliptic (
	deg2rad ($lat), deg2rad ($long), 1e12, $time)->equatorial;
    my $tolerance = 1e-6;
    foreach (['right ascension' => $ra, deg2rad ($expra)],
		[declination => $dec, deg2rad ($expdec)],
		) {
	$test++;
	my ($what, $got, $expect) = @$_;
	print <<eod;
# Test $test: Ecliptic latitude/longitude to right ascension/declination
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#      Quantity: $what
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs (($got - $expect) / $expect) < $tolerance);
	}
    }

use constant ASTRONOMICAL_UNIT => 149_597_870; # Meeus, Appendix 1, pg 407

#	Tests 55 - 57: Ecliptic lat/long to ECI
#	Tests: equatorial() (and ecliptic())

#	This test is based on Meeus' example 26.a.

foreach ([timegm (0, 0, 0, 13, 9, 92), .62 / 3600, 199.907347,
		.99760775, -0.9379952, -0.3116544, -0.1351215],
	) {
    my ($time, $lat, $long, $rho, $expx, $expy, $expz) = @$_;
    my ($x, $y, $z) = Astro::Coord::ECI->dynamical ($time)->
	ecliptic (deg2rad ($lat), deg2rad ($long), $rho * ASTRONOMICAL_UNIT)->eci;
    my $tolerance = 1e-5;
    foreach ([x => $x, $expx], [y => $y, $expy], [z => $z, $expz]) {
	$test++;
	my ($what, $got, $expect) = @$_;
	$expect = $expect * ASTRONOMICAL_UNIT;
	print <<eod;
# Test $test: Ecliptic latitude/longitude to ECI
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#      Quantity: $what
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs (($got - $expect) / $expect) < $tolerance);
	}
    }


#	Test 58: universal time to local mean time
#	Tests: local_mean_time()

#	This test is based on http://www.statoids.com/tconcept.html

foreach ([timegm (0, 0, 0, 1, 0, 101), 29/60 + 40, -(8/60 + 86),
		-((5 * 60 + 44) * 60 + 32)],
	) {
    my ($time, $lat, $lon, $offset) = @$_;
    my $got = Astro::Coord::ECI->
	geodetic (deg2rad ($lat), deg2rad ($lon), 0)->
	universal ($time)->local_mean_time;
    my $expect = $time + $offset;
    $test++;
    print <<eod;
# Test $test: universal time to local mean time
#          Time: @{[strftime TIMFMT, gmtime $time]} (universal)
#      Expected: @{[strftime TIMFMT, gmtime $expect]} (local mean)
#           Got: @{[strftime TIMFMT, gmtime $got]} (local mean)
eod
    ok ($expect == floor ($got + .5));
    }


#	Test 59: local mean time to universal time
#	Tests: local_mean_time()

#	This test is the inverse of the previous one.

foreach ([timegm (28, 15, 18, 31, 11, 100), 29/60 + 40, -(8/60 + 86),
		-((5 * 60 + 44) * 60 + 32)],
	) {
    my ($time, $lat, $lon, $offset) = @$_;
    my $got = Astro::Coord::ECI->
	geodetic (deg2rad ($lat), deg2rad ($lon), 0)->
	local_mean_time ($time)->universal;
    my $expect = $time - $offset;
    $test++;
    print <<eod;
# Test $test: local mean time to universal time
#          Time: @{[strftime TIMFMT, gmtime $time]} (universal)
#      Expected: @{[strftime TIMFMT, gmtime $expect]} (local mean)
#           Got: @{[strftime TIMFMT, gmtime $got]} (local mean)
eod
    ok ($expect == floor ($got + .5));
    }


#	Tests 60 - 62: Equatorial coordinates relative to observer.

#	I don't have a book solution for this, but if I turn off
#	atmospheric refraction, you should get the same result as if
#	you simply subtract the ECI coordinates of the observer from
#	the ECI coordinates of the body.


{	# Begin local symbol block;
my $time = time ();
my $station = Astro::Coord::ECI->geodetic (deg2rad (38.898741),
	deg2rad (-77.037684), 0.01668);
$station->set (refraction => 0);
my $body = Astro::Coord::ECI->eci (2328.97048951, -5995.22076416,
	1719.97067261, 2.91207230, -0.98341546, -7.09081703, $time);
my @staeci = $station->eci ($time);
my @bdyeci = $body->eci ();
my @want = Astro::Coord::ECI->eci (
	(map {$bdyeci[$_] - $staeci[$_]} 0 .. 5), $time)->
	equatorial ();
my @got = $station->equatorial ($body);
foreach (['right ascension' => $got[0], $want[0]],
	[declination => $got[1], $want[1]],
	[range => $got[2], $want[2]],
	) {
    $test++;
    my ($what, $got, $want) = @$_;
    print <<eod;
# Test $test: Equatorial coordinates relative to observer.
#      Quantity: $what
#           Got: $got
#      Expected: $want
eod
    ok (abs ($got - $want) < 0.000001);
    }
}	# End local symbol block.

#	Test 63 - 65: represents.

foreach ([[], 'Astro::Coord::ECI'],
	[['Astro::Coord::ECI'], 1],
	[['Astro::Coord::ECI::TLE'], 0],
	) {
    my ($arg, $want) = @$_;
    my $got = Astro::Coord::ECI->represents (@$arg);
    $test++;
    print <<eod;
# Test $test: Astro::Coord::ECI->represents (@{[map {"'$_'"} @$arg]})
#           Got: $got
#      Expected: $want
eod
    $want =~ m/\D/ ? ok ($got eq $want) : ok ($got == $want);
}

# Tests 66-68: Conversion of geodetic location to Maidenhead Locator
#     System. Reference implementation is at
#     http://home.arcor.de/waldemar.kebsch/The_Makrothen_Contest/fmaidenhead.html

foreach (
    [ 38.898748, -77.037684, 3, 'FM18lv' ],
    [ 38.898748, -77.037684, 2, 'FM18' ],
    [ 38.898748, -77.037684, 1, 'FM' ],
) {
    my ( $lat, $lon, $prec, $want ) = @{$_};
    my ( $got ) = Astro::Coord::ECI->new()->geodetic(
	deg2rad( $lat ),
	deg2rad( $lon ),
	0,
    )->maidenhead( $prec );
    $test++;
    print <<"EOD";
# Test $test: Latitude $lat, longitude $lon in Maidenhead system
#           Got: $got
#      Expected: $want
EOD
    ok( $got eq $want );
}

# Tests 69-72: Maidenhead to geodetic. Same reference implementation

foreach (
    [ 'FM18LV', 3, 38.896, -77.042 ],	# Reference gives -77.041
    [ 'FM18',   1, 38.5,   -77.0   ],
) {
    my ( $loc, $prec, $want_lat, $want_lon ) = @{$_};
    my ( $got_lat, $got_lon ) = Astro::Coord::ECI->new()->
    maidenhead( $loc )->geodetic();
    foreach (
	[ latitude => $want_lat, $got_lat ],
	[ longitude => $want_lon, $got_lon ],
    ) {
	my ( $dim, $want, $got ) = @{$_};
	my $check = sprintf "%.${prec}f", rad2deg( $got );
	$test++;
	print <<"EOD";
# Test $test: Maidenhead $loc $dim
#           Got: $check
#      Expected: $want
EOD
	ok( $want == $check );
    }
}

# need to test:
#    dip
#    get (class, object)
#    reference_ellipsoid
#    set (class, object with and without resetting the object)

1;
