use strict;
use warnings;

use Astro::Coord::ECI;
use Astro::Coord::ECI::Moon;
use Astro::Coord::ECI::Utils qw{deg2rad PI};
use POSIX qw{strftime floor};
use Test;
use Time::Local;

BEGIN {plan tests => 36}
use constant TIMFMT => '%d-%b-%Y %H:%M:%S';

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
#      Quantity: $what
#      Expected: $expect
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs (($got - $expect) / $expect) < $tolerance);
	}
    }

#	Test 4: phase of the moon.
#	Tests: phase ()

#	This test is based on Meeus' example 49.a, but worked backward.

foreach ([timegm (42, 37, 3, 18, 1, 1977), 0],
	) {
    $test++;
    my ($time, $expect) = @$_;
    $expect = deg2rad ($expect);
    my $got = Astro::Coord::ECI::Moon->dynamical ($time)->phase;
    my $tolerance = 1.e-4;	# A second's worth of radians.
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

#	Tests 5-6: Phase angle and illuminated fraction.

#	This test is based on Meeus' example 48.a.

foreach ([timegm (0, 0, 0, 12, 3, 1992), 180 - 69.0756, .6786],
	) {
    my ($time, $expph, $expil) = @$_;
    $expph = deg2rad ($expph);
    my ($phase, $illum) =
	Astro::Coord::ECI::Moon->dynamical ($time)->phase ();
    foreach ([phase => $phase, $expph, 3.e-3],
	    [illumination => $illum, $expil, .01],
	    ) {
	my ($what, $got, $expect, $tolerance) = @$_;
	$test++;
	print <<eod;
# Test $test: Phase and illumination
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#      Quantity: $what
#      Expected: $expect
#           Got: $got
#     Tolerance: $tolerance
eod
	ok (abs ($got - $expect) < $tolerance);
	}
    }


#	Tests 7-8: next_quarter and next_quarter_hash

#	This test is based on Meeus' example 49.1, right way around.

foreach ([timegm (0, 0, 0, 1, 1, 1977), 0, timegm (42, 37, 3, 18, 1, 1977)],
	) {
    $test++;
    my ($time, $quarter, $expect) = @$_;
    my $moon = Astro::Coord::ECI::Moon->new();
    my $tolerance = 2;

    my $got = $moon->dynamical ($time)->next_quarter ($quarter);
    print <<eod;
# Test $test: Next quarter after given time.
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#       Quarter: $quarter
#      Expected: @{[strftime TIMFMT, gmtime $expect]} (dynamical)
#           Got: @{[strftime TIMFMT, gmtime $got]} (dynamical)
#     Tolerance: $tolerance seconds
eod
    ok (abs ($got - $expect) < $tolerance);

    $got = $moon->dynamical($time)->next_quarter_hash($quarter);
    print <<eod;
# Test $test: Next quarter after given time, as hash
#          Time: @{[strftime TIMFMT, gmtime $time]} (dynamical)
#       Quarter: $quarter
#      Expected: @{[strftime TIMFMT, gmtime $expect]} (dynamical)
#           Got: @{[strftime TIMFMT, gmtime $got->{time}]} (dynamical)
#     Tolerance: $tolerance seconds
eod
    ok (abs ($got->{time} - $expect) < $tolerance);
    }


#	Tests 9 - 10: Singleton object

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
	    local $Astro::Coord::ECI::Moon::Singleton = $sgl;
	    my @moon = map {Astro::Coord::ECI::Moon->new} (0 .. 1);
	    Scalar::Util::refaddr ($moon[0]) ==
		Scalar::Util::refaddr ($moon[1]) ? 1 : 0;
	    } unless $skip;
	$test++;
	print <<eod;
# Test $test: \$Astro::Coord::ECI::Moon::Singleton = $sgl
#      Expected: $text[$expect]
#           Got: @{[$skip ? 'skipped' : $text[$got]]}
eod
	skip ($skip, $skip || $got eq $expect);
	}
    }

#	Tests 11-36: almanac() and almanac_hash, testing against data
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

    my $moon = Astro::Coord::ECI::Moon->new();

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
	my @list = $moon->universal($time)->$method($sta);

	$test++;
	print <<eod;
# Test $test: Items returned by $method()
#      Expected: 3
#           Got: @{[scalar @list]}
eod
	ok (scalar @list == 3);

	my $inx = 0;
	foreach my $info (
	    [timegm(0, 15,  6, 1, 0, 108), horizon => 1, 'Moon rise'],
	    [timegm(0, 46, 11, 1, 0, 108), transit => 1, 'Moon transits meridian'],
	    [timegm(0,  8, 17, 1, 0, 108), horizon => 0, 'Moon set'],
	) {
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
	    $inx++;
	}
    }
}
__END__
