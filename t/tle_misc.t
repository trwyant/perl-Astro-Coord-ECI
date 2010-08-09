package main;

use strict;
use warnings;

BEGIN {
    eval {
	require Test::More;
	Test::More->VERSION( 0.40 );
	Test::More->import();
	1;
    } or do {
	print "1..0 # skip Test::More 0.40 required\n";
	exit;
    }
}

use Astro::Coord::ECI::TLE qw{ :constants };

plan( tests => 12 );

my $tle = Astro::Coord::ECI::TLE->new();

ok( $tle->body_type() == BODY_TYPE_UNKNOWN,
    'TLE without name is unknown body type' );

test_body_type( $tle, 'Misc deb', BODY_TYPE_DEBRIS );

test_body_type( $tle, 'Miscellaneous debris', BODY_TYPE_DEBRIS );

test_body_type( $tle, 'Dumped coolant', BODY_TYPE_DEBRIS );

test_body_type( $tle, 'Ejected shroud', BODY_TYPE_DEBRIS );

test_body_type( $tle, 'Westford needles', BODY_TYPE_DEBRIS );

test_body_type( $tle, 'R/B debris', BODY_TYPE_DEBRIS );

test_body_type( $tle, 'Delta R/B', BODY_TYPE_ROCKET_BODY );

test_body_type( $tle, 'Foosat akm', BODY_TYPE_ROCKET_BODY );

test_body_type( $tle, 'Foosat pkm', BODY_TYPE_ROCKET_BODY );

test_body_type( $tle, 'Foosat', BODY_TYPE_PAYLOAD );

test_body_type( $tle, 'Debut', BODY_TYPE_PAYLOAD );

sub test_body_type {	## no critic (RequireArgUnpacking)
    my ( $body, $name, $want ) = @_;
    $body->set( name => $name );
    @_ = ( eval { $body->body_type() } == $want,
	"Name '$name' represents $want" );
    goto &ok;
}

1;

# ex: set textwidth=72 :
