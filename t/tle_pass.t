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
use Astro::Coord::ECI::TLE qw{ :constants };
use Astro::Coord::ECI::Utils qw{ deg2rad rad2deg };

my $sta = Astro::Coord::ECI->new(
    name => 'Greenwich Observatory',
)->geodetic(
    deg2rad( 51.4772 ),
    0,
    2 / 1000,
);

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

plan 'no_plan';

my @pass;

if (
    eval {
	@pass = $tle->pass(
	    $sta,
	    timegm( 0, 0, 0, 12, 9, 80 ),
	    timegm( 0, 0, 0, 19, 9, 80 ),
	);
	1;
    }
) {
    ok @pass == 6, 'Found 6 passes over Greenwich'
} else {
    fail "Error in pass() method: $@";
}

is format_pass( $pass[0] ), <<'EOD', 'Pass 1';
1980/10/13 05:39:02   0.0 199.0  1687.8 lit   rise
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
	$rslt .= sprintf '%s %5.1f %5.1f %7.1f %-5s %-5s',
	    format_time( $event->{time} ),
	    rad2deg( $event->{elevation} ),
	    rad2deg( $event->{azimuth} ),
	    $event->{range},
	    format_event( $event->{illumination} ),
	    format_event( $event->{event} ),
	    ;
	$rslt =~ s/ \s+ \z //smx;
	$rslt .= "\n";
    }
    $rslt =~ s/ (?<= \s ) - (?= 0 [.] 0+ \s ) / /smxg;
    return $rslt;
}

sub format_time {
    my ( $time ) = @_;
    my @parts = gmtime $time;
    return sprintf '%04d/%02d/%02d %02d:%02d:%02d', $parts[5] + 1900,
	$parts[4] + 1, @parts[ 3, 2, 1, 0 ];
}

1;

# ex: set textwidth=72 :
