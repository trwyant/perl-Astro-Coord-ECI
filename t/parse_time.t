package main;

use strict;
use warnings;

my ( $mock_time, $time_y2038 );

BEGIN {
    eval {
	require Test::More;
	Test::More->VERSION( 0.40 );
	Test::More->import();
	1;
    } or do {
	print "1..0 # skip Test::More 0.40 required for test.
";
	exit;
    };

    eval {
	require Time::y2038;
	Time::y2038->import();
	$time_y2038 = 1;
    } or do {
	require Time::Local;
	Time::Local->import();
    };

    eval {
	require Test::MockTime;
	Test::MockTime->import( qw{ set_fixed_time restore_time } );

	$mock_time = 1;
    };
}

use Astro::Coord::ECI::Utils ();

if ( $mock_time && $time_y2038 ) {

    # This is yukky, but we have to do it because if
    # Astro::Coord::ECI::Utils was able to import Time::y2038, the
    # relevant core routines have already been overridden in that
    # module's namespace, and Test::MockTime's CORE::GLOBAL override
    # will not be seen.

    no warnings qw{ redefine once };
    *Astro::Coord::ECI::Utils::time = \&Test::MockTime::time;
    *Astro::Coord::ECI::Utils::localtime = \&Test::MockTime::localtime;
    *Astro::Coord::ECI::Utils::gmtime = \&Test::MockTime::gmtime;

}

plan( 'no_plan' );

lcl( '20090702162337',		37, 23, 16, 2, 6, 109 );
gmt( '20090702162337Z',		37, 23, 16, 2, 6, 109 );
lcl( '200907021623',		0, 23, 16, 2, 6, 109 );
gmt( '200907021623Z',		0, 23, 16, 2, 6, 109 );
lcl( '2009070216',		0, 0, 16, 2, 6, 109 );
gmt( '2009070216Z',		0, 0, 16, 2, 6, 109 );
lcl( '20090702',		0, 0, 0, 2, 6, 109 );
gmt( '20090702Z',		0, 0, 0, 2, 6, 109 );
lcl( '200907',			0, 0, 0, 1, 6, 109 );
gmt( '200907Z',			0, 0, 0, 1, 6, 109 );
lcl( '2009',			0, 0, 0, 1, 0, 109 );
gmt( '2009Z',			0, 0, 0, 1, 0, 109 );

lcl( '20090102162337',		37, 23, 16, 2, 0, 109 );
gmt( '20090102162337Z',		37, 23, 16, 2, 0, 109 );
lcl( '200901021623',		0, 23, 16, 2, 0, 109 );
gmt( '200901021623Z',		0, 23, 16, 2, 0, 109 );
lcl( '2009010216',		0, 0, 16, 2, 0, 109 );
gmt( '2009010216Z',		0, 0, 16, 2, 0, 109 );
lcl( '20090102',		0, 0, 0, 2, 0, 109 );
gmt( '20090102Z',		0, 0, 0, 2, 0, 109 );
lcl( '200901',			0, 0, 0, 1, 0, 109 );
gmt( '200901Z',			0, 0, 0, 1, 0, 109 );

gmt( '20090102162337+00',	37, 23, 16, 2, 0, 109 );
gmt( '20090102162337+0030',	37, 53, 15, 2, 0, 109 );
gmt( '20090102162337+01',	37, 23, 15, 2, 0, 109 );
gmt( '20090102162337-0030',	37, 53, 16, 2, 0, 109 );
gmt( '20090102162337-01',	37, 23, 17, 2, 0, 109 );

lcl( '20090102T162337',		37, 23, 16, 2, 0, 109 );
gmt( '20090102T162337Z',	37, 23, 16, 2, 0, 109 );

lcl( '2009/1/2 16:23:37',	37, 23, 16, 2, 0, 109 );
gmt( '2009/1/2 16:23:37 Z',	37, 23, 16, 2, 0, 109 );
lcl( '2009/1/2 16:23',		0, 23, 16, 2, 0, 109 );
gmt( '2009/1/2 16:23 Z',	0, 23, 16, 2, 0, 109 );
lcl( '2009/1/2 16',		0, 0, 16, 2, 0, 109 );
gmt( '2009/1/2 16 Z',		0, 0, 16, 2, 0, 109 );
lcl( '2009/1/2',		0, 0, 0, 2, 0, 109 );
gmt( '2009/1/2 Z',		0, 0, 0, 2, 0, 109 );
lcl( '2009/1',			0, 0, 0, 1, 0, 109 );
gmt( '2009/1 Z',		0, 0, 0, 1, 0, 109 );
lcl( '2009',			0, 0, 0, 1, 0, 109 );
gmt( '2009 Z',			0, 0, 0, 1, 0, 109 );

lcl( '09/1/2 16:23:37',		37, 23, 16, 2, 0, 109 );
gmt( '09/1/2 16:23:37 Z',	37, 23, 16, 2, 0, 109 );
lcl( '09/1/2 16:23',		0, 23, 16, 2, 0, 109 );
gmt( '09/1/2 16:23 Z',		0, 23, 16, 2, 0, 109 );
lcl( '09/1/2 16',		0, 0, 16, 2, 0, 109 );
gmt( '09/1/2 16 Z',		0, 0, 16, 2, 0, 109 );
lcl( '09/1/2',			0, 0, 0, 2, 0, 109 );
gmt( '09/1/2 Z',		0, 0, 0, 2, 0, 109 );
lcl( '09/1',			0, 0, 0, 1, 0, 109 );
gmt( '09/1 Z',			0, 0, 0, 1, 0, 109 );

SKIP: {

    $mock_time or skip( 'Unable to load Test::MockTime', 12 );

    set_fixed_time('2009-07-01T06:00:00Z');

    gmt( 'yesterday Z',		0, 0, 0, 30, 5, 109 );
    gmt( 'yesterday 9:30Z',	0, 30, 9, 30, 5, 109 );
    gmt( 'today Z',		0, 0, 0, 1, 6, 109 );
    gmt( 'today 9:30Z',		0, 30, 9, 1, 6, 109 );
    gmt( 'tomorrow Z',		0, 0, 0, 2, 6, 109 );
    gmt( 'tomorrow 9:30Z',	0, 30, 9, 2, 6, 109 );

    restore_time();
    set_fixed_time( timelocal( 0, 0, 6, 1, 6, 109 ) );

    lcl( 'yesterday',		0, 0, 0, 30, 5, 109 );
    lcl( 'yesterday 9:30',	0, 30, 9, 30, 5, 109 );
    lcl( 'today',		0, 0, 0, 1, 6, 109 );
    lcl( 'today 9:30',		0, 30, 9, 1, 6, 109 );
    lcl( 'tomorrow',		0, 0, 0, 2, 6, 109 );
    lcl( 'tomorrow 9:30',	0, 30, 9, 2, 6, 109 );

    restore_time();

}

sub gmt {
    my ( $string, @gmt ) = @_;
    my $want = timegm( @gmt );
    my $got = eval {
	Astro::Coord::ECI::Utils::_parse_time_iso_8601( $string );
    };
    $@ and $got = $@;
    @_ = ( $got, $want, "$string => " . gmtime( $want ) . ' GMT' );
    goto &is;
}

sub lcl {
    my ( $string, @local ) = @_;
    my $want = timelocal( @local );
    my $got = eval {
	Astro::Coord::ECI::Utils::_parse_time_iso_8601( $string );
    };
    $@ and $got = $@;
    @_ = ( $got, $want, "$string => " . localtime( $want ) . ' local' );
    goto &is;
}

1;

# ex: set textwidth=72 :
