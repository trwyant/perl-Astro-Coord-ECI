package main;

use strict;
use warnings;

use Astro::Coord::ECI;
use Astro::Coord::ECI::TLE;
use Astro::Coord::ECI::TLE::Iridium;
use Astro::Coord::ECI::Utils qw{ :time deg2rad };
use Cwd;
use File::Spec;
use FileHandle;
use Test;

BEGIN {plan tests => 9};

my $test = 0;

#	Test 1: Instantiate

{	# Local symbol block
    my $tle = Astro::Coord::ECI::TLE->new ();
    $tle->rebless ('iridium');
    $test++;
    print <<eod;
# Test $test: Rebless TLE to Iridium
#     Expecting: 'Astro::Coord::ECI::TLE::Iridium'
#           Got: '@{[ref $tle]}'
eod
    ok (ref $tle eq 'Astro::Coord::ECI::TLE::Iridium');
    $tle->rebless ('tle');
    $test++;
    print <<eod;
# Test $test: Rebless Iridium back to TLE
#     Expecting: 'Astro::Coord::ECI::TLE'
#           Got: '@{[ref $tle]}'
eod
    ok (ref $tle eq 'Astro::Coord::ECI::TLE');
    }	# End local symbol block

my $datafile = File::Spec->catfile (getcwd, qw{t iridium.dat});
my $skip = -e $datafile ? '' : 'Must provide iridium.dat';
$skip and warn <<eod;


Flare prediction tests require file t/iridium.dat. This needs to
contain NORAD IDs 24905, 24965, 25104, 25285, 25288, and 25577 for June
5, 2006. If you have the Astro::SpaceTrack package installed, you can
obtain these yourself using the SpaceTrack command-line utility, or with
this package. Assuming you have not installed this package yet, set your
default to your, working directory, and proceed as follows:

\$ perl -Mblib bin/satpass
    (front matter printed here)
satpass> st retrieve -start 2006/06/04 -end 2006/06/06 \\
_satpass> 24905 24965 25104 25285 25288 25577
satpass> choose -time 'June 6 2006 midnight'
satpass> tle >t/iridium.dat
satpass> exit

Obviously I have this file, but I do not have permission to
redistribute the elements.

eod

my ($end, @flares, @irid, $start, $station);
unless ($skip) {
    $station = Astro::Coord::ECI->new (
	name => '1600 Pennsylvania Ave NW Washington DC 20502',
	)->geodetic (
	deg2rad (38.898748),
	deg2rad (-77.037684),
	0.017,
	);
    $start = timegm (0, 0, 4, 6, 5, 106);
    $end = timegm (0, 0, 4, 8, 5, 106);
    my $twilight = deg2rad (-6);	# Civil twilight
    my $horizon = deg2rad (20);		# Effective horizon
    my $fh = FileHandle->new ("<$datafile") or die <<eod;
Error - Failed to open $datafile
        $!
eod
    @irid = Astro::Coord::ECI::TLE->parse (<$fh>);
    foreach my $tle (@irid) {
	$tle->set (twilight => $twilight, horizon => $horizon);
	$tle->rebless ('iridium');
	push @flares, $tle->flare ($station, $start, $end);
	}
    @flares = map {$_->[1]}
	sort {$a->[0] <=> $b->[0]}
	map {[$_->{time}, $_]} @flares;
    }

$test++;
print <<eod;
# Test $test: Number of flares found.
#    Expected: 7
#         Got: @{[scalar @flares]}
eod
skip ($skip, @flares == 7);

foreach ([am => 2], [day => 4], [pm => 1]) {
    my ($type, $expect) = @$_;
    $test++;
    my $got = grep {$_->{type} eq $type} @flares;
    print <<eod;
# Test $test: Number of $type flares found.
#    Expected: $expect
#         Got: $got
eod
    skip ($skip, $got == $expect);
    }

foreach ([1, time => timegm (13, 24, 9, 6, 5, 106), 1, sub {scalar gmtime $_[0]}],
	[1, magnitude => -8, .1],
	[1, mma => 2, 0],
	) {
    $test++;
    my ($inx, $what, $expect, $tolerance, $fmtr) = @$_;
    $fmtr ||= sub {$_[0]};
    my $got = $flares[$inx]->{$what} || 0;
    print <<eod;
# Test $test: Flare $inx (from 0) $what
#    Expected: @{[$fmtr->($expect)]}
#         Got: @{[$fmtr->($got)]}
#   Tolerance: $tolerance
eod
    skip ($skip, abs ($expect - $got) <= $tolerance);
    }

1;
#	If you wish to run the flare prediction tests

__END__

foreach (
	[[qw{day pm}], 4], [[qw{am pm}], 5], [[qw{am day}], 7],
	[[qw{am}], 4], [[qw{day}], 3], [[qw{pm}], 1],
	) {
    my ($types, $expect) = @$_;
    @flares = ();
    foreach my $tle (@irid) {
	$tle->set (am => 0, day => 0, pm => 0);
	$tle->set (map {$_ => 1} @$types);
	push @flares, $tle->flare ($station, $start, $end);
	}
    my $what = join ' and ', @$types;
    my $got = @flares;
    print <<eod;
# Test $test: Flares generated by type: $what
#    Expected: $expect
#         Got: $got
eod
    skip ($skip, $expect == $got);
    }

1;
