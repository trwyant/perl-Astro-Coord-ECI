package main;

use 5.006002;

use strict;
use warnings;

use Astro::Coord::ECI::TLE;
use Time::Local;

use Test::More 0.88;	# Because of done_testing();

my ( $want, $got );

# All TLE data from "Revisiting Spacetrack Report Number 3". See
# ACKNOWLEDGMENTS section of Astro::Coord::ECI::TLE documentation for
# the details. The data may have been modified for the purposes of
# testing.

ok eval { ( $want ) = Astro::Coord::ECI::TLE->parse( <<'EOD' ); 1 },
VANGUARD 1
1 00005U 08002B   00009.78495062  .00000023      0-0  00098-4 0  0053
2 00005  04.2682 008.7242 0000067 001.7664  09.3264 01.82419157413667
EOD
    'Parse generic TLE.'
    or diag $@;

ok eval { ( $got ) = Astro::Coord::ECI::TLE->parse( <<'EOD' ); 1 },
VANGUARD 1
1     5U  8  2B    0  9.78495062  .00000023      0-0     98-4 0    53
2     5   4.2682   8.7242      67   1.7664   9.3264  1.82419157413667
EOD
    'Parse TLE with leading spaces.'
    or diag $@;

foreach my $attr ( qw{ international } ) {
    cmp_ok $got->get( $attr ), 'eq', $want->get( $attr ),
	"Got expected '$attr' value";
}

foreach my $attr ( qw{ id epoch firstderivative secondderivative
    bstardrag ephemeristype elementnumber inclination ascendingnode
    eccentricity argumentofperigee meananomaly meanmotion
    revolutionsatepoch }
) {
    cmp_ok $got->get( $attr ), '==', $want->get( $attr ),
	"Got expected '$attr' value";
}

done_testing;

1;

# ex: set textwidth=72 :
