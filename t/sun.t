package main;

use strict;
use warnings;

use Astro::Coord::ECI;
use Astro::Coord::ECI::Sun;
use Astro::Coord::ECI::Utils qw{deg2rad};
use POSIX qw{strftime floor};
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

BEGIN {plan tests => 67}

use constant EQUATORIALRADIUS => 6378.14;	# Meeus page 82.
use constant TIMFMT => '%d-%b-%Y %H:%M:%S';
use constant ASTRONOMICAL_UNIT => 149_597_870; # Meeus, Appendix 1, pg 407

my $test = 0;


#	Tests 1 - 3: sun position in ecliptic latitude/longitude
#	Tests: ::Sun->time_set() (and ecliptic())

#	This test is based on Meeus' example 25.a.

#	Note that we're not too picky about the position of the sun, since it's
#	an extended object. One part in a thousand is less than half its disk.

foreach ([timegm (0, 0, 0, 13, 9, 92), 199.90895, .99766, 199.90988],
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

foreach ([timegm (0, 0, 0, 20, 2, 105), 53/60 + 38, -(2/60 + 77), -5,
		timegm (0, 11, 6, 20, 2, 105),
		timegm (0, 16, 12, 20, 2, 105),
		timegm (0, 20, 18, 20, 2, 105)],
	[timegm (0, 0, 0, 21, 5, 105), 53/60 + 38, -(2/60 + 77), -5,
		timegm (0, 43, 4, 21, 5, 105),
		timegm (0, 10, 12, 21, 5, 105),
		timegm (0, 37, 19, 21, 5, 105)],
	[timegm (0, 0, 0, 22, 8, 105), 53/60 + 38, -(2/60 + 77), -5,
		timegm (0, 56, 5, 22, 8, 105),
		timegm (0, 1, 12, 22, 8, 105),
		timegm (0, 5, 18, 22, 8, 105)],
	[timegm (0, 0, 0, 21, 11, 105), 53/60 + 38, -(2/60 + 77), -5,
		timegm (0, 23, 7, 21, 11, 105),
		timegm (0, 6, 12, 21, 11, 105),
		timegm (0, 50, 16, 21, 11, 105)],
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

#	Tests 16 - 23: Equinoxes and Solstices for 2005
#	Tests: next_quarter(), next_quarter_hash()

#	This test is based on Meeus' table 27.E on page 182. The
#	accuracy is a fairly poor 16 minutes 40 seconds, because
#	our  position of the Sun is only good to 0.01 degrees.

foreach ([timegm (0, 0, 0, 1, 0, 105),
		timegm (29, 34, 12, 20, 2, 105),
		timegm (12, 47, 6, 21, 5, 105),
		timegm (14, 24, 22, 22, 8, 105),
		timegm ( 1, 36, 18, 21, 11, 105)],
	) {
    my $year = (gmtime $_->[0])[5] + 1900;
    my $time = shift @$_;
    my $sun = Astro::Coord::ECI::Sun->universal ($time);
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
    $sun->universal ($time);
    foreach my $expect (@$_) {
	$test++;
####	my ($got, undef, $quarter) = $sun->next_quarter;
	my $hash = $sun->next_quarter_hash();
	my $got = $sun->dynamical;
	print <<eod;
# Test $test: $hash->{almanac}{description} $year
#      Expected: @{[strftime TIMFMT, gmtime $expect]} (dynamical)
#           Got: @{[strftime TIMFMT, gmtime $got]} (dynamical)
#     Tolerance: $tolerance seconds
eod
	ok (abs ($got - $expect) <= $tolerance);
	}
    }

#	Tests 24 - 25: Singleton object

{	# Local symbol block.
    my $skip;
    eval {
	local $@;
	$skip = "Can not load Scalar::Util.";
	require Scalar::Util;
	$skip = "Scalar::Util does not implement refaddr ().";
	Scalar::Util->can('refaddr')
	    and $skip = undef;
    };
    my @text = qw{different same};

    foreach ([1, 1], [0, 0]) {
	my ($sgl, $expect) = @$_;
	my $got;
	$skip or $got =  do {
	    local $Astro::Coord::ECI::Sun::Singleton = $sgl;
	    my @sun = map {Astro::Coord::ECI::Sun->new} (0 .. 1);
	    Scalar::Util::refaddr ($sun[0]) ==
		Scalar::Util::refaddr ($sun[1]) ? 1 : 0;
	    };
	$test++;
	print <<eod;
# Test $test: \$Astro::Coord::ECI::Sun::Singleton = $sgl
#      Expected: $text[$expect]
#           Got: @{[$skip ? 'skipped' : $text[$got]]}
eod
	skip ($skip, $skip || $got eq $expect);
	}
    }

#	Tests 26-67: almanac() and almanac_hash, testing against data
#	from the U. S. Naval Observatory

{
    my $sta = Astro::Coord::ECI->new(
	name => 'Washington, DC'
    )->geodetic(
	deg2rad(38.9),	# Position according to
	deg2rad(-77.0),	# U. S. Naval Observatory's
	0,		# http://aa.usno.navy.mil/data/docs/RS_OneDay.php
    );
    my $time = timegm (0, 0, 5, 1, 0, 108);	# Jan 1, 2008 in TZ -5

    my $sun = Astro::Coord::ECI::Sun->new();

    my @title = qw{time event detail description};
    my @accessor = (
	[sub {$_[0][0]}, sub {$_[0][1]}, sub {$_[0][2]}, sub {$_[0][3]}],
	[sub {$_[0]{time}}, sub {$_[0]{almanac}{event}},
	sub {$_[0]{almanac}{detail}}, sub {$_[0]{almanac}{description}}]
    );
    my @test = (
	sub {skip ($_[0], abs ($_[2] - $_[1]) < 60)},
	sub {skip ($_[0], $_[1] eq $_[2])},
	sub {skip ($_[0], $_[1] == $_[2])},
	sub {skip ($_[0], $_[1] eq $_[2])},
    );

    foreach my $hash (0 .. 1) {
	my $method = $hash ? 'almanac_hash' : 'almanac';
	my @list = $sun->universal($time)->$method($sta);

	$test++;
	print <<eod;
# Test $test: Items returned by $method()
#      Expected: 6
#           Got: @{[scalar @list]}
eod
	ok (scalar @list == 6);

	my $inx = 0;
	foreach my $info (
	    undef,	# Local midnight not in Naval Observatory data
	    [timegm(0, 57, 11, 1, 0, 108), twilight => 1, 'begin twilight'],
	    [timegm(0, 27, 12, 1, 0, 108), horizon => 1, 'Sunrise'],
	    [timegm(0, 12, 17, 1, 0, 108), transit => 1, 'local noon'],
	    [timegm(0, 56, 21, 1, 0, 108), horizon => 0, 'Sunset'],
	    [timegm(0, 26, 22, 1, 0, 108), twilight => 0, 'end twilight'],
	) {
	    $info or next;
	    my $skip = $inx >= @list ? "Index $inx not returned" : undef;
	    foreach my $item (0 .. 3) {
		my $got = $accessor[$hash][$item]->($list[$inx]);
		$test++;
		print <<eod;
# Test $test: Item $inx $title[$item]
#     Expected: $info->[$item]
#          Got: $got
eod
		$inx or print <<eod;
#    Tolerance: 60
eod
		$test[$item]->($skip, $info->[$item], $got);
	    }
	} continue {
	    $inx++;
	}
    }
}

1;
