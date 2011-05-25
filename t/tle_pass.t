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
    };
}

BEGIN {
    eval {
	require Time::Local;
	Time::Local->import();
	1;
    } or do {
	plan skip_all => 'Can not load Time::Local';
	exit;
    };
}

use Astro::Coord::ECI;
use Astro::Coord::ECI::Moon;
use Astro::Coord::ECI::Star;
use Astro::Coord::ECI::TLE qw{ :constants };
use Astro::Coord::ECI::TLE::Set;
use Astro::Coord::ECI::Utils qw{ deg2rad PARSEC rad2deg SECSPERDAY };

my $sta = Astro::Coord::ECI->new(
    name => 'Greenwich Observatory',
)->geodetic(
    deg2rad( 51.4772 ),
    0,
    2 / 1000,
);

use constant SPY2DPS => 3600 * 365.24219 * SECSPERDAY;

my $star = do {
    my $ra = deg2rad( 146.4625 );
    Astro::Coord::ECI::Star->new(
	name	=> 'Epsilon Leonis',
    )->position(
	$ra,
	deg2rad( 23.774 ),
	76.86 * PARSEC,
	deg2rad( -0.0461 * 24 / 360 / cos( $ra ) / SPY2DPS ),
	deg2rad( -0.00957 / SPY2DPS ),
	4.3,
    );
};

# The following TLE is from
#
# SPACETRACK REPORT NO. 3
#
# Models for Propagation of
# NORAD Element Sets
#
# Felix R. Hoots
# Ronald L. Roerich
#
# December 1980
#
# Package Compiled by
# TS Kelso
#
# 31 December 1988
#
# obtained from http://celestrak.com/

# There is no need to call Astro::Coord::ECI::TLE::Set->aggregate()
# because we know we have exactly one data set.

my ( $tle ) = Astro::Coord::ECI::TLE->parse( <<'EOD' );
1 88888U          80275.98708465  .00073094  13844-3  66816-4 0    8
2 88888  72.8435 115.9689 0086731  52.6988 110.5714 16.05824518  105
EOD
$tle->set( geometric => 1 );

plan tests => 45;

my @pass;

if (
    eval {
	@pass = $tle->pass(
	    $sta,
	    timegm( 0, 0, 0, 12, 9, 80 ),
	    timegm( 0, 0, 0, 19, 9, 80 ),
	    [ $star ],
	);
	1;
    }
) {
    ok @pass == 6, 'Found 6 passes over Greenwich'
	or diag "Found @{[ scalar @pass ]} passes over Greenwich";
} else {
    fail "Error in pass() method: $@";
}

is format_pass( $pass[0] ), <<'EOD', 'Pass 1';
1980/10/13 05:39:02   0.0 199.0  1687.8 lit   rise
1980/10/13 05:42:42  55.8 119.1   255.7 lit   apls
                     49.6 118.3     6.2 Epsilon Leonis
1980/10/13 05:42:43  55.9 115.6   255.5 lit   max
1980/10/13 05:46:37   0.0  29.7  1778.5 lit   set
EOD

is format_pass( $pass[1] ), <<'EOD', 'Pass 2';
1980/10/14 05:32:49   0.0 204.8  1691.2 lit   rise
1980/10/14 05:36:32  85.6 111.4   215.0 lit   max
1980/10/14 05:40:27   0.0  27.3  1782.5 lit   set
EOD

is format_pass( $pass[2] ), <<'EOD', 'Pass 3';
1980/10/15 05:26:29   0.0 210.3  1693.5 shdw  rise
1980/10/15 05:27:33   4.7 212.0  1220.0 lit   lit
1980/10/15 05:30:12  63.7 297.6   239.9 lit   max
1980/10/15 05:34:08   0.0  25.1  1789.5 lit   set
EOD

is format_pass( $pass[3] ), <<'EOD', 'Pass 4';
1980/10/16 05:20:01   0.0 215.7  1701.3 shdw  rise
1980/10/16 05:22:20  14.8 228.1   701.8 lit   lit
1980/10/16 05:23:44  43.5 299.4   310.4 lit   max
1980/10/16 05:27:40   0.0  23.0  1798.7 lit   set
EOD

is format_pass( $pass[4] ), <<'EOD', 'Pass 5';
1980/10/17 05:13:26   0.0 221.0  1706.4 shdw  rise
1980/10/17 05:16:45  28.6 273.8   433.1 lit   lit
1980/10/17 05:17:08  31.7 301.4   400.0 lit   max
1980/10/17 05:21:03   0.0  21.0  1809.7 lit   set
EOD

is format_pass( $pass[5] ), <<'EOD', 'Pass 6';
1980/10/18 05:06:44   0.0 226.2  1708.2 shdw  rise
1980/10/18 05:10:23  24.5 302.6   495.7 shdw  max
1980/10/18 05:10:50  22.3 327.2   537.6 lit   lit
1980/10/18 05:14:16   0.0  19.0  1814.7 lit   set
EOD

SKIP: {

    # This file contains the TLE needed to test various corner cases.
    # But the data come from Space Track (http://www.space-track.org/,
    # account needed) and I do not have permission to redistribute them.
    # What you need is:
    #
    # OID   Epoch (GMT)          Epoch (in TLE)
    # ----- -------------------- --------------
    # 25544 25-Apr-2011 08:32:05 11115.35561462
    # 25544 13-May-2011 11:58:29 11133.49894455
    #
    # These can be either NORAD format (i.e. true two-line format) or
    # NASA format (i.e. three-line format), and order is unimportant.

    my $file = 'ref/iss.tle';
    my $tests = 38;

    our $SKIP_TEST
	and skip $SKIP_TEST, $tests;

    -f $file
	or skip "$file not found", $tests;

    $sta = Astro::Coord::ECI->new(
	name	=> 'Twisst',
    )->geodetic(
	deg2rad( 51.8 ),
	deg2rad( 5.3 ),
	0,
    );

    my $moon = Astro::Coord::ECI::Moon->new();

    our $/ = undef;

    open my $fh, '<', $file
	or skip "Unable to open $file: $!", $tests;
    my $data = <$fh>;
    close $fh;

    ( $tle ) = Astro::Coord::ECI::TLE::Set->aggregate(
	Astro::Coord::ECI::TLE->parse( $data ) );
    $tle->set( horizon => deg2rad( 10 ) );

    @pass = ();
    my $offset = 10;
    if ( eval {
	    @pass = $tle->pass(
		$sta,
		timegm( $offset, 0, 10, 25, 3, 111 ),
		timegm( $offset, 0, 10,  2, 4, 111 ),
		[ $moon ],
	    );
	    1;
	} ) {
	ok @pass == 10,
	    "Found 10 passes over Twisst at $offset sec after minute"
	    or diag "Found @{[ scalar @pass ]} passes over Twisst";
    } else {
	fail "Error in pass() method: $@";
    }

    is format_pass( $pass[0] ), <<'EOD', 'Pass 1';
2011/04/25 20:29:44  10.1 274.3  1311.4 lit   rise
2011/04/25 20:32:40  85.5 178.7   352.9 lit   max
2011/04/25 20:34:18  23.2  98.6   792.2 shdw  shdw
2011/04/25 20:35:36   9.9  97.9  1317.9 shdw  set
EOD

    is format_pass( $pass[1] ), <<'EOD', 'Pass 2';
2011/04/25 22:05:01  10.1 273.1  1309.8 lit   rise
2011/04/25 22:05:46  15.7 265.9  1030.7 shdw  shdw
2011/04/25 22:07:43  34.5 205.5   589.1 shdw  max
2011/04/25 22:10:26   9.9 137.5  1314.0 shdw  set
EOD

    is format_pass( $pass[2] ), <<'EOD', 'Pass 3';
2011/04/26 20:54:23  10.0 277.1  1313.9 lit   rise
2011/04/26 20:57:17  60.9 195.5   398.9 lit   max
2011/04/26 20:57:52  46.5 142.8   472.9 shdw  shdw
2011/04/26 21:00:10  10.0 115.1  1310.1 shdw  set
EOD

    is format_pass( $pass[3] ), <<'EOD', 'Pass 4';
2011/04/27 19:43:46  10.0 274.6  1312.4 lit   rise
2011/04/27 19:46:42  84.8 182.0   353.1 lit   max
2011/04/27 19:49:38   9.9  98.5  1317.0 lit   set
EOD

    is format_pass( $pass[4] ), <<'EOD', 'Pass 5';
2011/04/27 21:19:03  10.1 272.7  1310.4 lit   rise
2011/04/27 21:21:22  32.0 223.9   623.4 shdw  shdw
2011/04/27 21:21:44  33.5 206.0   602.1 shdw  max
2011/04/27 21:24:26   9.9 138.7  1312.5 shdw  set
EOD

    is format_pass( $pass[5] ), <<'EOD', 'Pass 6';
2011/04/28 20:08:18  10.1 277.0  1311.1 lit   rise
2011/04/28 20:11:11  59.6 196.7   403.6 lit   max
2011/04/28 20:13:20  16.1 118.9  1012.8 shdw  shdw
2011/04/28 20:14:05   9.9 116.0  1316.0 shdw  set
EOD

    is format_pass( $pass[6] ), <<'EOD', 'Pass 7';
2011/04/28 21:43:59  10.0 258.6  1309.6 lit   rise
2011/04/28 21:44:48  13.9 244.5  1106.9 shdw  shdw
2011/04/28 21:45:59  16.9 215.3   978.9 shdw  max
2011/04/28 21:48:00   9.9 171.4  1309.0 shdw  set
EOD

    is format_pass( $pass[7] ), <<'EOD', 'Pass 8';
2011/04/29 20:32:50  10.0 272.4  1312.6 lit   rise
2011/04/29 20:35:31  32.6 205.9   614.1 lit   max
2011/04/29 20:36:43  22.6 160.3   805.6 shdw  shdw
2011/04/29 20:38:11  10.0 139.9  1308.8 shdw  set
EOD

    is format_pass( $pass[8] ), <<'EOD', 'Pass 9';
2011/04/30 20:57:40  10.0 257.8  1310.6 lit   rise
2011/04/30 20:59:38  16.5 215.4   995.9 lit   max
2011/04/30 21:00:03  16.0 204.4  1012.0 shdw  shdw
2011/04/30 21:01:35  10.0 173.2  1305.2 shdw  set
EOD

    is format_pass( $pass[9] ), <<'EOD', 'Pass 10';
2011/05/01 19:46:23  10.1 272.1  1309.5 lit   rise
2011/05/01 19:49:02  31.8 206.8   624.9 lit   max
2011/05/01 19:51:42   9.9 140.9  1309.4 lit   set
EOD

    @pass = ();
    $offset = 54;
    if ( eval {
	    @pass = $tle->pass(
		$sta,
		timegm( $offset, 0, 10, 25, 3, 111 ),
		timegm( $offset, 0, 10,  2, 4, 111 ),
		[ $moon ],
	    );
	    1;
	} ) {
	ok @pass == 10,
	    "Found 10 passes over Twisst at $offset sec after minute"
	    or diag "Found @{[ scalar @pass ]} passes over Twisst";
    } else {
	fail "Error in pass() method: $@";
    }

    is format_pass( $pass[0] ), <<'EOD', 'Pass 1';
2011/04/25 20:29:44  10.1 274.3  1311.4 lit   rise
2011/04/25 20:32:40  85.5 178.7   352.9 lit   max
2011/04/25 20:34:18  23.2  98.6   792.2 shdw  shdw
2011/04/25 20:35:36   9.9  97.9  1317.9 shdw  set
EOD

    is format_pass( $pass[1] ), <<'EOD', 'Pass 2';
2011/04/25 22:05:01  10.1 273.1  1309.8 lit   rise
2011/04/25 22:05:46  15.7 265.9  1030.7 shdw  shdw
2011/04/25 22:07:43  34.5 205.5   589.1 shdw  max
2011/04/25 22:10:26   9.9 137.5  1314.0 shdw  set
EOD

    is format_pass( $pass[2] ), <<'EOD', 'Pass 3';
2011/04/26 20:54:23  10.0 277.1  1313.9 lit   rise
2011/04/26 20:57:17  60.9 195.5   398.9 lit   max
2011/04/26 20:57:52  46.5 142.8   472.9 shdw  shdw
2011/04/26 21:00:10  10.0 115.1  1310.1 shdw  set
EOD

    is format_pass( $pass[3] ), <<'EOD', 'Pass 4';
2011/04/27 19:43:46  10.0 274.6  1312.4 lit   rise
2011/04/27 19:46:42  84.8 182.0   353.1 lit   max
2011/04/27 19:49:38   9.9  98.5  1317.0 lit   set
EOD

    is format_pass( $pass[4] ), <<'EOD', 'Pass 5';
2011/04/27 21:19:03  10.1 272.7  1310.4 lit   rise
2011/04/27 21:21:22  32.0 223.9   623.4 shdw  shdw
2011/04/27 21:21:44  33.5 206.0   602.1 shdw  max
2011/04/27 21:24:26   9.9 138.7  1312.5 shdw  set
EOD

    is format_pass( $pass[5] ), <<'EOD', 'Pass 6';
2011/04/28 20:08:18  10.1 277.0  1311.1 lit   rise
2011/04/28 20:11:11  59.6 196.7   403.6 lit   max
2011/04/28 20:13:20  16.1 118.9  1012.8 shdw  shdw
2011/04/28 20:14:05   9.9 116.0  1316.0 shdw  set
EOD

    is format_pass( $pass[6] ), <<'EOD', 'Pass 7';
2011/04/28 21:43:59  10.0 258.6  1309.6 lit   rise
2011/04/28 21:44:48  13.9 244.5  1106.9 shdw  shdw
2011/04/28 21:45:59  16.9 215.3   978.9 shdw  max
2011/04/28 21:48:00   9.9 171.4  1309.0 shdw  set
EOD

    is format_pass( $pass[7] ), <<'EOD', 'Pass 8';
2011/04/29 20:32:50  10.0 272.4  1312.6 lit   rise
2011/04/29 20:35:31  32.6 205.9   614.1 lit   max
2011/04/29 20:36:43  22.6 160.3   805.6 shdw  shdw
2011/04/29 20:38:11  10.0 139.9  1308.8 shdw  set
EOD

    is format_pass( $pass[8] ), <<'EOD', 'Pass 9';
2011/04/30 20:57:40  10.0 257.8  1310.6 lit   rise
2011/04/30 20:59:38  16.5 215.4   995.9 lit   max
2011/04/30 21:00:03  16.0 204.4  1012.0 shdw  shdw
2011/04/30 21:01:35  10.0 173.2  1305.2 shdw  set
EOD

    is format_pass( $pass[9] ), <<'EOD', 'Pass 10';
2011/05/01 19:46:23  10.1 272.1  1309.5 lit   rise
2011/05/01 19:49:02  31.8 206.8   624.9 lit   max
2011/05/01 19:51:42   9.9 140.9  1309.4 lit   set
EOD

    $sta = Astro::Coord::ECI->new(
	name	=> 'Bogota',
    )->geodetic(
	deg2rad( 4.656370 ),
	deg2rad( -74.117790 ),
	46 / 1000,
    );
    $tle->set( horizon => deg2rad( 11 ), twilight => deg2rad( -3 ) );

    @pass = ();
    $offset = 34;
    if ( eval {
	    @pass = $tle->pass(
		$sta,
		timegm( $offset, 0, 17, 13, 4, 111 ),
		timegm( $offset, 0, 17, 20, 4, 111 ),
		[ $moon ],
	    );
	    1;
	} ) {
	ok @pass == 7,
	    "Found 7 passes over Bogota at $offset sec after minute"
	    or diag "Found @{[ scalar @pass ]} passes over Bogota";
    } else {
	fail "Error in pass() method: $@";
    }

    is format_pass( $pass[0] ), <<'EOD', 'Pass 1';
2011/05/14 00:32:45  11.0 244.1  1237.5 lit   rise
2011/05/14 00:33:11  11.3 234.9  1223.3 lit   max
2011/05/14 00:33:39  11.0 225.1  1239.4 lit   set
EOD

    is format_pass( $pass[1] ), <<'EOD', 'Pass 2';
2011/05/14 23:19:14  11.1 319.6  1232.4 lit   rise
2011/05/14 23:21:58  73.2 232.8   359.7 lit   max
2011/05/14 23:24:43  10.9 149.4  1245.3 lit   set
EOD

    is format_pass( $pass[2] ), <<'EOD', 'Pass 3';
2011/05/15 23:45:28  11.0 237.6  1238.1 lit   rise
2011/05/15 23:45:36  11.0 234.8  1236.9 lit   max
2011/05/15 23:45:44  11.0 232.0  1238.3 lit   set
EOD

    is format_pass( $pass[3] ), <<'EOD', 'Pass 4';
2011/05/17 09:59:17  11.0 154.7  1236.0 lit   rise
2011/05/17 10:00:38  13.9 125.1  1091.2 lit   max
2011/05/17 10:01:59  11.0  95.5  1236.0 lit   set
EOD

    is format_pass( $pass[4] ), <<'EOD', 'Pass 5';
2011/05/18 10:21:25  11.1 217.9  1230.4 lit   rise
2011/05/18 10:24:09  81.8 307.8   347.4 lit   max
2011/05/18 10:26:53  11.0  33.4  1233.7 lit   set
EOD

    is format_pass( $pass[5] ), <<'EOD', 'Pass 6';
2011/05/19 09:11:21  11.0 155.1  1233.2 shdw  rise
2011/05/19 09:12:10  13.4 138.2  1109.8 lit   lit
2011/05/19 09:12:43  14.0 125.1  1084.3 lit   max
2011/05/19 09:14:06  10.9  94.7  1237.1 lit   set
EOD

    is format_pass( $pass[6] ), <<'EOD', 'Pass 7';
2011/05/20 09:33:24  11.1 218.1  1230.7 shdw  rise
2011/05/20 09:35:30  50.2 226.7   439.8 shdw  apls
                     50.3 226.0     0.5 Moon
2011/05/20 09:35:31  50.6 226.9   437.4 lit   lit
2011/05/20 09:36:08  81.0 307.4   347.6 lit   max
2011/05/20 09:38:52  11.0  33.1  1233.7 lit   set
EOD

    @pass = ();
    $offset = 44;
    if ( eval {
	    @pass = $tle->pass(
		$sta,
		timegm( $offset, 0, 17, 13, 4, 111 ),
		timegm( $offset, 0, 17, 20, 4, 111 ),
		[ $moon ],
	    );
	    1;
	} ) {
	ok @pass == 7,
	    "Found 7 passes over Bogota at $offset sec after minute"
	    or diag "Found @{[ scalar @pass ]} passes over Bogota";
    } else {
	fail "Error in pass() method: $@";
    }

    is format_pass( $pass[0] ), <<'EOD', 'Pass 1';
2011/05/14 00:32:45  11.0 244.1  1237.5 lit   rise
2011/05/14 00:33:11  11.3 234.9  1223.3 lit   max
2011/05/14 00:33:39  11.0 225.1  1239.4 lit   set
EOD

    is format_pass( $pass[1] ), <<'EOD', 'Pass 2';
2011/05/14 23:19:14  11.1 319.6  1232.4 lit   rise
2011/05/14 23:21:58  73.2 232.8   359.7 lit   max
2011/05/14 23:24:43  10.9 149.4  1245.3 lit   set
EOD

    is format_pass( $pass[2] ), <<'EOD', 'Pass 3';
2011/05/15 23:45:28  11.0 237.6  1238.1 lit   rise
2011/05/15 23:45:36  11.0 234.8  1236.9 lit   max
2011/05/15 23:45:44  11.0 232.0  1238.3 lit   set
EOD

    is format_pass( $pass[3] ), <<'EOD', 'Pass 4';
2011/05/17 09:59:17  11.0 154.7  1236.0 lit   rise
2011/05/17 10:00:38  13.9 125.1  1091.2 lit   max
2011/05/17 10:01:59  11.0  95.5  1236.0 lit   set
EOD

    is format_pass( $pass[4] ), <<'EOD', 'Pass 5';
2011/05/18 10:21:25  11.1 217.9  1230.4 lit   rise
2011/05/18 10:24:09  81.8 307.8   347.4 lit   max
2011/05/18 10:26:53  11.0  33.4  1233.7 lit   set
EOD

    is format_pass( $pass[5] ), <<'EOD', 'Pass 6';
2011/05/19 09:11:21  11.0 155.1  1233.2 shdw  rise
2011/05/19 09:12:10  13.4 138.2  1109.8 lit   lit
2011/05/19 09:12:43  14.0 125.1  1084.3 lit   max
2011/05/19 09:14:06  10.9  94.7  1237.1 lit   set
EOD

    is format_pass( $pass[6] ), <<'EOD', 'Pass 7';
2011/05/20 09:33:24  11.1 218.1  1230.7 shdw  rise
2011/05/20 09:35:30  50.2 226.7   439.8 shdw  apls
                     50.3 226.0     0.5 Moon
2011/05/20 09:35:31  50.6 226.9   437.4 lit   lit
2011/05/20 09:36:08  81.0 307.4   347.6 lit   max
2011/05/20 09:38:52  11.0  33.1  1233.7 lit   set
EOD

}

########################################################################

{

    my @decoder;

    # We jump through this hoop in case the constants turn out not to be
    # dualvars.
    BEGIN {
	$decoder[ PASS_EVENT_NONE  + 0 ]	= '';
	$decoder[ PASS_EVENT_SHADOWED  + 0 ]	= 'shdw';
	$decoder[ PASS_EVENT_LIT  + 0 ]		= 'lit';
	$decoder[ PASS_EVENT_DAY  + 0 ]		= 'day';
	$decoder[ PASS_EVENT_RISE  + 0 ]	= 'rise';
	$decoder[ PASS_EVENT_MAX  + 0 ]		= 'max';
	$decoder[ PASS_EVENT_SET  + 0 ]		= 'set';
	$decoder[ PASS_EVENT_APPULSE  + 0 ]	= 'apls';
    }

    sub format_event {
	my ( $event ) = @_;
	defined $event or return '';
	return $decoder[ $event + 0 ];
    }

}

sub format_pass {
    my ( $pass ) = @_;
    my $rslt = '';
    $pass or return $rslt;
    foreach my $event ( @{ $pass->{events} } ) {
	$rslt .= sprintf '%19s %5.1f %5.1f %7.1f %-5s %-5s',
	    format_time( $event->{time} ),
	    rad2deg( $event->{elevation} ),
	    rad2deg( $event->{azimuth} ),
	    $event->{range},
	    format_event( $event->{illumination} ),
	    format_event( $event->{event} ),
	    ;
	$rslt =~ s/ \s+ \z //smx;
	$rslt .= "\n";
	if ( $event->{appulse} ) {
	    my ( $az, $el ) = $sta->azel(
		$event->{appulse}{body}->universal( $event->{time} ) );
	    $rslt .= sprintf '%19s %5.1f %5.1f %7.1f %s', '',
		rad2deg( $el ),
		rad2deg( $az ),
		rad2deg( $event->{appulse}{angle} ),
		$event->{appulse}{body}->get( 'name' ),
		;
	    $rslt =~ s/ \s+ \z //smx;
	    $rslt .= "\n";
	}
    }
    $rslt =~ s/ (?<= \s ) - (?= 0 [.] 0+ \s ) / /smxg;
    return $rslt;
}

sub format_time {
    my ( $time ) = @_;
    my @parts = gmtime int( $time + 0.5 );
    return sprintf '%04d/%02d/%02d %02d:%02d:%02d', $parts[5] + 1900,
	$parts[4] + 1, @parts[ 3, 2, 1, 0 ];
}

1;

# ex: set textwidth=72 :
