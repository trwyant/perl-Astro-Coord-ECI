package main;

use 5.006002;

use strict;
use warnings;

BEGIN {
    eval {
	require Test::More;
	Test::More->VERSION( 0.40 );
	Test::More->import();
	1;
    } or do {
	print "1..0 # skip Test::More 0.40 required\\n";
	exit;
    }
}

use Astro::Coord::ECI::TLE;
use Astro::Coord::ECI::TLE::Iridium;
use Astro::Coord::ECI::Utils qw{ deg2rad };
use Time::Local;

plan( tests => 11 );

my ( $tle ) = Astro::Coord::ECI::TLE->parse( <<'EOD' );
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    8
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  105
EOD

is( ref $tle, 'Astro::Coord::ECI::TLE', 'Created a TLE object' );

$tle->rebless( 'iridium' );

is( ref $tle, 'Astro::Coord::ECI::TLE::Iridium', 'Reblessed to Iridium' );

$tle->set( zone => 0 );	# Zone 0 for -am/-pm determination

my $sta = Astro::Coord::ECI->new()->geodetic(
    deg2rad( 51.4772 ),
    deg2rad( 0 ),
    0 / 1000,
)->set( name => 'Royal Observatory, Greenwich England' );

my $start    = timegm( 0, 0, 0, 13, 9, 80 );
my $finish   = timegm( 0, 0, 0, 14, 9, 80 );
my $twilight = deg2rad( -6 );	# Civil twilight
my $horizon  = deg2rad( 20 );	# Effective horizon

$tle->set( twilight => $twilight, horizon => $horizon );

my @flares = $tle->flare( $sta, $start, $finish );

is( scalar @flares, 2, 'Got 2 flares' );

is( sprintf( '%d', $flares[0]{time} ), timegm( 26, 43, 5, 13, 9, 80 ),
    'Time of first flare is 13-Oct-1980 5:43:26 GMT' );
is( $flares[0]{type}, 'am', q{Type of first flare is 'am'} );
is( sprintf( '%.1f', $flares[0]{magnitude} ), '-0.4',
    'Magnitude of first flare is -0.4' );
is( $flares[0]{mma}, 1, 'Flaring MMA of first flare is 1' );

is( sprintf( '%d', $flares[1]{time} ), timegm( 33, 58, 14, 13, 9, 80 ),
    'Time of second flare is 13-Oct-1980 14:58:33 GMT' );
is( $flares[1]{type}, 'day', q{Type of second flare is 'day'} );
is( sprintf( '%.1f', $flares[1]{magnitude} ), '-3.0',
    'Magnitude of second flare is -3.0' );
is( $flares[1]{mma}, 1, 'Flaring MMA of second flare is 1' );

1;

# ex: set textwidth=72 :
